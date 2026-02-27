---
title: UE4-距离场阴影DistanceFieldShadow # 标题
date: 2024-04-05
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

## 1.UE的DistanceField
距离场的生成，有MeshDistanceField和GlobalDistanceField

UE的主要应用是DFShadow、DFAO、材质DistanceFieldToNearest

https://dev.epicgames.com/documentation/en-us/unreal-engine/mesh-distance-fields-in-unreal-engine

<!--more-->

## 2.DFShadow流程

### SceneProxy 收集MeshBatch

<center><img src="https://pic1.zhimg.com/80/v2-1b01697d97edc2e336c2bd550a614b83_720w.png" width = "" height = ""></center>

### DistanceField数据上传

这一步上传所有SceneProxy的相关距离场数据，一堆float4的数据。
每帧有Remove，Update，Add的处理。

上传Buffer用的是一个ComputeShader，后来改引擎的时候又加了一个ComputeShader用来单独上传Buffer里的某段数据，来更新东西实现功能。

<center><img src="https://pic1.zhimg.com/80/v2-cb0fd6492e44a212a1037d16c877e539_720w.png" width = "" height = ""></center>

### DFShadow计算

DFShadow在光照阶段计算，共有3步：剔除划分->计算阴影->上采样并合并CSM

<center><img src="https://pic1.zhimg.com/80/v2-bf5ef2faa523e30cfb194b254e0bfa84_720w.png" width = "" height = ""></center>



#### 1.CullObjectsForLight-剔除划分Tile阶段

CullObjectToFrustum ：
使用CSM的视锥平面剔除Object、HISM同步Cull也是在这里剔除掉的

------------使用的CullObjectsForShadowCS这个CS剔除，没剔除的就把这些数据Copy到新的Buffer里

ComputeTileStartOffsets：计算每个Tile相交的Object，并把Object分配到这些Tile里，记录下Tile的索引Offset

------------第一次ScatterObjectsToShadowTiles：计算出来每个Tile里有多少个Object

------------ComputeCulledTileStartOffsetCS：计算每个Tile的索引Offset

CullObjectsToTiles：

------------第二次ScatterObjectsToShadowTiles：前面知道了每个Tile的Object数量和Tile的Offset，这里最后主要是把RWShadowTileArrayData[DataIndex]填充了，它的长度是所有Tile的Object数量之和，它的值是ObjectIndex（就是CullObjectToFrustum这步的CopyData的索引）

RenderDoc上看的流程：
<center><img src="https://picx.zhimg.com/80/v2-b2337b9e96994f6fca8dc260e2cf490c_720w.png" width = "" height = ""></center>


#### 2.DFShadow计算

```
[numthreads(THREADGROUP_SIZEX, THREADGROUP_SIZEY, 1)]
void DistanceFieldShadowingCS(
    uint3 GroupId : SV_GroupID,
    uint3 DispatchThreadId : SV_DispatchThreadID,
    uint3 GroupThreadId : SV_GroupThreadID) 
{
    //和其他ComputeShader算法一样，转换DispatchThreadId为屏幕UV和屏幕坐标
      uint ThreadIndex = GroupThreadId.y * THREADGROUP_SIZEX + GroupThreadId.x;
    float2 ScreenUV = float2((DispatchThreadId.xy * DownsampleFactor + ScissorRectMinAndSize.xy + .5f) * View.BufferSizeAndInvSize.zw);
    float2 ScreenPosition = (ScreenUV.xy - View.ScreenPositionScaleBias.wz) / View.ScreenPositionScaleBias.xy;
   
   //深度转换为世界坐标
    float SceneDepth = CalcSceneDepth(ScreenUV);
    float3 OpaqueWorldPosition = mul(float4(ScreenPosition * SceneDepth, SceneDepth, 1), View.ScreenToWorld).xyz;

   //得到DFTrace的射线起点和终点，其实就是往灯光方向去打射线，和ContactShadow一样
      float3 WorldRayStart = OpaqueWorldPosition + LightDirection * RayStartOffset;
    float3 WorldRayEnd = OpaqueWorldPosition + LightDirection * TraceDistance;
  
   //遍历所有的CullObject，先判断射线是否与物体包围盒相交
   //IntersectionTimes得到最近交点和最远交点
   float2 IntersectionTimes = LineBoxIntersect(...);
           
   BRANCH                                            
   if (IntersectionTimes.x < IntersectionTimes.y)
   {
          //如果有相交，就在包围盒内RayMarching，逐步采样距离场，如果值小于一个阈值，代表很接近这个物体了，可以结束循环，此时距离场信息作为阴影的值。如果已经RayMarch超出包围盒也结束循环。
      LOOP
        for (; StepIndex < MaxSteps; StepIndex++)
      {
            float3 SampleVolumePosition = VolumeRayStart + VolumeRayDirection * SampleRayTime;
            float3 ClampedSamplePosition = clamp(SampleVolumePosition, -LocalPositionExtent, LocalPositionExtent);
            float DistanceToClamped = length(ClampedSamplePosition - SampleVolumePosition);
            float3 VolumeUV = DistanceFieldVolumePositionToUV(ClampedSamplePosition, UVScaleAndVolumeScale.xyz, UVAddAndSelfShadowBias.xyz);
            float DistanceField = SampleMeshDistanceField(VolumeUV, DistanceFieldMAD).x + DistanceToClamped;
        
         MinDistance = min(MinDistance, DistanceField);
        
        float SphereRadius = clamp(TanLightAngle * SampleRayTime, VolumeMinSphereRadius, VolumeMaxSphereRadius);
            float StepVisibility = max(saturate(DistanceField / SphereRadius), SelfShadowVisibility);
        
         MinConeVisibility = min(MinConeVisibility, StepVisibility);

            float StepDistance = max(abs(DistanceField), MinStepSize);
            SampleRayTime += StepDistance;

            // Terminate the trace if we are fully occluded or went past the end of the ray
            if (MinConeVisibility < .01f
            || SampleRayTime > IntersectionTimes.y * VolumeRayLength)
            {
                break;
            }
      }
      MinConeVisibility = min(MinConeVisibility, (1 - StepIndex / (float)MaxSteps));
   }
   
  return MinConeVisibility;
}

```

#### 3.UpSample 和 合并CSM

RenderRayTracedDistanceFieldProjection()
DFshadow半分辨率计算结果，这里需要上采样，中间还穿插了和CSM进行Fade的操作

```
void DistanceFieldShadowingUpsamplePS(
    in float4 UVAndScreenPos : TEXCOORD0,
    in float4 SVPos : SV_POSITION,
    out float4 OutColor : SV_Target0)
{
    float2 DistanceFieldUVs = UVAndScreenPos.xy - ScissorRectMinAndSize.xy * View.BufferSizeAndInvSize.zw;
    float SceneDepth = CalcSceneDepth(UVAndScreenPos.xy);
  
   float Output = Texture2DSampleLevel(ShadowFactorsTexture, ShadowFactorsSampler, DistanceFieldUVs, 0).x;
      float FarBlendFactor = 1.0f - saturate((SceneDepth - FadePlaneOffset) * InvFadePlaneLength);
    Output = lerp(1, Output, FarBlendFactor);

    float NearBlendFactor = saturate((SceneDepth - NearFadePlaneOffset) * InvNearFadePlaneLength);
    Output = lerp(1, Output, NearBlendFactor);

    OutColor = EncodeLightAttenuation(half4(Output, Output, Output, Output));
}
```