---
title: UE4-关于植被HISM屏占比LOD的选择和切换 # 标题
date: 2023-09-05
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---


UE的Mesh关于LOD的切换是用的屏占比ScreenSize，一般是美术设置几个屏占比的参数，本地看着差不多就行了。

下面研究下这个屏占比在引擎里是怎么运作的，方便理解和优化功能。


## Q:这个ScreenSize是怎么生效的？

A：ScreenSize先转换为距离，后续以距离的形式剔除和选择LOD。

## Q:ScreenSize是如何转换成距离的?

A：通过下面这个方法，把LOD的各个级别的ScreenSize转换为Distance，保存在LOD信息里。

也就是说，如果屏幕是方的的情况下：

ScreenSize如果是0.5，绘制距离范围就是物体包围球半径的两倍。

ScreenSize如果是1，绘制距离范围就是物体包围球半径。

ScreenSize如果是2，绘制距离范围就是物体包围球半径的一半。

如果屏幕是16：9的的情况下：

ScreenSize如果是0.5，绘制距离范围就是物体包围球半径的3.56倍。

ScreenSize如果是1，绘制距离范围就是物体包围球半径的1.78倍。

ScreenSize如果是2，绘制距离范围就是物体包围球半径的0.89倍。

```
float ComputeBoundsDrawDistance(const float ScreenSize, const float SphereRadius, const FMatrix& ProjMatrix)
{
    // Get projection multiple accounting for view scaling.
   //获得屏幕宽高比，正常屏幕都是宽>高，结果就是0.5f * ProjMatrix.M[1][1]
   //16：9就是 0.5f * 1.7778f
    const float ScreenMultiple = FMath::Max(0.5f * ProjMatrix.M[0][0], 0.5f * ProjMatrix.M[1][1]);

   // ScreenSize * 0.5f
    const float ScreenRadius = FMath::Max(SMALL_NUMBER, ScreenSize * 0.5f);

    //计算距离
    return (ScreenMultiple * SphereRadius) / ScreenRadius;
}
```

## HISM的LOD选择过程
在FHierarchicalStaticMeshSceneProxy::GetDynamicMeshElements里，渲染线程里用来收集当前HISM的MeshElement。
里面通过Cluster结构进行HISM的 视锥剔除、遮挡剔除、距离剔除、LOD选择。

核心方法是在FHierarchicalStaticMeshSceneProxy::Traverse()里

```
FHierarchicalStaticMeshSceneProxy::Traverse()
{
    //视锥剔除ViewFrustum Cull
  
   //距离剔除(这里距离剔除是用LOD组的最远一级的距离进行剔除)
   //Cluster的包围盒中心到摄像机的距离 与每一级LOD的距离进行对比，得到最小LOD和最大LOD。
   CalcLOD(MinLOD, MaxLOD, BoundMin, BoundMax, ViewOriginInLocalZero, ViewOriginInLocalOne, LODPlanesMin, LODPlaneMax);
  
   //遮挡剔除
  
   //是否可以把当前ClusterNode直接用一个LOD级别渲染
   //如果一个LODGroup就会return了，如果不能一个，继续往下面级别的ClusterNode遍历
   //只要不被剔除掉，这里就会设置当前Instance使用什么LOD级别渲染
   //因为涉及到LODDither切换的情况，这里会传进去两个LOD级别
    Params.AddRun(MinLOD, MaxLOD, Node.FirstInstance, Node.LastInstance);
  
   //继续往下递归Traverse()
}
```

## DitherLOD Transition
当材质开启DitherLODTransition开关之后，会有渐变的lod切换。

在ShaderBind过程中，Alpha是获取一个LODTransition值，这个值是通过一个公式计算：

(真实上一帧时间 - DelayTime - 保存的上上帧时间)  / (保存的上一帧时间 - 保存的上上帧时间)

```
    float GetTemporalLODTransition(float LastRenderTime) const
    {
        if (TemporalLODLag == 0.0)
        {
            return 0.0f; // no fade
        }
        return FMath::Clamp((LastRenderTime - TemporalLODLag - TemporalLODTime[0]) / (TemporalLODTime[1] - TemporalLODTime[0]), 0.0f, 1.0f);
    }
```

DelayTime就是切换的时间，在引擎的另一个地方，当帧间隔大于DelayTime，才会去保存TemporalLODTime。

LODTransition的值就会慢慢变大，到DelayTime的时候就到达1。

```
	if (!View.bDisableDistanceBasedFadeTransitions)
	{
		bOk = true;
		TemporalLODLag = CVarLODTemporalLag.GetValueOnRenderThread();
		if (TemporalLODTime[1] < LastRenderTime - TemporalLODLag)
		{
			if (TemporalLODTime[0] < TemporalLODTime[1])
			{
				TemporalLODViewOrigin[0] = TemporalLODViewOrigin[1];
				TemporalLODTime[0] = TemporalLODTime[1];
			}
			TemporalLODViewOrigin[1] = View.ViewMatrices.GetViewOrigin();
			TemporalLODTime[1] = LastRenderTime;
			if (TemporalLODTime[1] <= TemporalLODTime[0])
			{
				bOk = false; // we are paused or something or otherwise didn't get a good sample
			}
		}
	}
```

把两个AlphaCutOff的值传给Shader:

InstancingWorldViewOriginOne.W，

InstancingWorldViewOriginZero.W

然后还有一个InstancingViewZCompareZero和InstancingViewZCompareOne，通过两次循环分别设置两层(或者两帧)的对比距离。

```
            for (int32 SampleIndex = 0; SampleIndex < 2; SampleIndex++)
            {
                FVector4& InstancingViewZCompare(SampleIndex ? InstancingViewZCompareOne : InstancingViewZCompareZero);

                float FinalCull = MAX_flt;
                if (MinSize > 0.0)
                {
                    FinalCull = ComputeBoundsDrawDistance(MinSize, SphereRadius, View->ViewMatrices.GetProjectionMatrix()) * LODScale;
                }
                if (InstancingUserData->EndCullDistance > 0.0f)
                {
                    FinalCull = FMath::Min(FinalCull, InstancingUserData->EndCullDistance * MaxDrawDistanceScale);
                }
                FinalCull *= MaxDrawDistanceScale;

                InstancingViewZCompare.Z = FinalCull;
                if (int(BatchElement.InstancedLODIndex) < InstancingUserData->MeshRenderData->LODResources.Num() - 1)
                {
                    float NextCut = ComputeBoundsDrawDistance(InstancingUserData->MeshRenderData->ScreenSize[BatchElement.InstancedLODIndex + 1].GetValue(), SphereRadius, View->ViewMatrices.GetProjectionMatrix()) * LODScale;
                    InstancingViewZCompare.Z = FMath::Min(NextCut, FinalCull);
                }

                InstancingViewZCompare.X = MIN_flt;
                if (int(BatchElement.InstancedLODIndex) > FirstLOD)
                {
                    float CurCut = ComputeBoundsDrawDistance(InstancingUserData->MeshRenderData->ScreenSize[BatchElement.InstancedLODIndex].GetValue(), SphereRadius, View->ViewMatrices.GetProjectionMatrix()) * LODScale;
                    if (CurCut < FinalCull)
                    {
                        InstancingViewZCompare.Y = CurCut;
                    }
                    else
                    {
                        // this LOD is completely removed by one of the other two factors
                        InstancingViewZCompare.Y = MIN_flt;
                        InstancingViewZCompare.Z = MIN_flt;
                    }
                }
                else
                {
                    // this is the first LOD, so we don't have a fade-in region
                    InstancingViewZCompare.Y = MIN_flt;
                }
            }

            InstancingOffset = InstancingUserData->InstancingOffset;
            InstancingWorldViewOriginZero = View->GetTemporalLODOrigin(0);
            InstancingWorldViewOriginOne = View->GetTemporalLODOrigin(1);

            float Alpha = View->GetTemporalLODTransition();
            InstancingWorldViewOriginZero.W = 1.0f - Alpha;
            InstancingWorldViewOriginOne.W = Alpha;

            InstancingViewZCompareZero.W = LODRandom;
        }
```

  
在Shader里：

Intermediates.PerInstanceParams.w会在后续PS里作为CutOff值进行像素丢弃。

```
Intermediates.PerInstanceParams.x = GetInstanceRandom(Intermediates);
    float3 InstanceLocation = TransformLocalToWorld(GetInstanceOrigin(Intermediates), Intermediates.PrimitiveId).xyz;
    Intermediates.PerInstanceParams.y = 1.0 - saturate((length(InstanceLocation + ResolvedView.PreViewTranslation.xyz) - InstancingFadeOutParams.x) * InstancingFadeOutParams.y);
    // InstancingFadeOutParams.z,w are RenderSelected and RenderDeselected respectively.
    Intermediates.PerInstanceParams.z = InstancingFadeOutParams.z * SelectedValue + InstancingFadeOutParams.w * (1-SelectedValue);
    #if USE_DITHERED_LOD_TRANSITION
        float RandomLOD = InstancingViewZCompareZero.w * Intermediates.PerInstanceParams.x;
        float ViewZZero = length(InstanceLocation - InstancingWorldViewOriginZero.xyz) + RandomLOD;
        float ViewZOne = length(InstanceLocation - InstancingWorldViewOriginOne.xyz) + RandomLOD;
        Intermediates.PerInstanceParams.w = 
            dot(float3(ViewZZero.xxx > InstancingViewZCompareZero.xyz), InstancingViewZConstant.xyz) * InstancingWorldViewOriginZero.w +
            dot(float3(ViewZOne.xxx > InstancingViewZCompareOne.xyz), InstancingViewZConstant.xyz) * InstancingWorldViewOriginOne.w;
        Intermediates.PerInstanceParams.z *= abs(Intermediates.PerInstanceParams.w) < .999;
    #else
        Intermediates.PerInstanceParams.w = 0;
    #endif
```

