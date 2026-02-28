---
title: UE4-HISM剔除更新DFShadow # 标题
date: 2023-09-04
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

修改基于UE4.27，实际代码因为UE5重构了，还没写UE5版本。

记录一下DFShadow随Cluster裁剪更新的修改过程。
(上次UE直播好像说5.3重构了GPUScene相关)

# 遇到的问题：

植被Instance的DistanceFieldShadow不会随着自身裁剪而更新。UE5应该还存在这个问题，美术同学会提出来这个问题的。

造成的原因是UE的DistanceFieldBuffer是基于SceneInfo级别的，一种植被对应一 个FoliageInstanceStaticMeshComponent，一个SceneInfo。因为是静态物体，UE只会在初始化或者被标记修改了之后才会去更新Buffer，而标记更新并不会在运行时进行，编辑器下刷植被删植被会标记更新。运行时植被的Instance被裁剪剔除，并不会标记修改，也就不会更新Buffer。

# 修改后效果
<center><img src="https://pic1.zhimg.com/v2-04b4a1b8021aa41f950dccae2245d784.gif" width = "" height = ""></center>

# 默认的更新逻辑：

### DeferredRenderer.Render()
```

-InitViews--->计算可见性的GatherDynamicMeshElements里

---FHierarchicalStaticMeshSceneProxy::GetDynamicMeshElements   //HISM SceneProxy收集MeshBatch

---Traverse() //做基于ClusterTree的视锥剔除

---FillDynamicMeshElements() //填充MeshBatch
```

### PrepareDistanceFieldScene

```
-UpdateGlobalDistanceFieldObjectBuffers //更新DF ObjectBuffer

---ProcessPrimitiveUpdate //Add的

---ProcessPrimitiveUpdate //Update的

---UpdateGlobalHeightFieldObjectBuffers //高度场相关Buffer

---UpdateGlobalDistanceFieldVolume //合成GlobalDistanceField
```

### RenderLight
```

-RenderShadowProjection

-RenderRayTracedDistanceFieldProjection

---CullDistanceFieldObjectsForLight

---CullObjectsForShadowCS（DispatchComputeShader）

---RayTracedShadows //DFShadow计算
```

## 主要方法：

### 1.FHierarchicalStaticMeshSceneProxy::GetDynamicMeshElements

根据植被设置的CullDistance，生成一个视锥六面体剔除掉不显示的Instance。

ClusterNode的结构：
<center><img src="https://picx.zhimg.com/80/v2-e25a2cf6fe2516f8024614ef5004c1be_720w.png" width = "" height = ""></center>


一个例子：81个实例的Cluster树的结构，剔除的时候从上往下，如果上面节点被剔除，下面叶子就可以跳过。
如果使用地形笔刷添加删除植被，ClusterTree就会重建。

<center><img src="https://picx.zhimg.com/80/v2-07c2b096bee08457ea174640796c0b88_720w.png" width = "" height = ""></center>


### 2.UpdateGlobalDistanceFieldObjectBuffers

ProcessPrimitiveUpdate() 只在Add和标记修改时触发更新Buffer

上传DistanceFieldObjectBuffer的数据，这个数据数对应Instance的实例数。

DistanceFieldObjectBuffers是被当作ComputeShader的RWBuffer使用，有两个结构体。一个是ObjectBoundingSphere包围球(一个float4坐标+半径)，另一个是ObjectData(很多组float，两个矩阵和一些其他数据)。

RWBuffer是没有分成两个结构体，是一个连续的float4数组，通过内存Offset来控制写入。
  

默认情况呢，就是按照物体级别进行上传，一个物体18个float4，使用ComputeShader  TUploadObjectsToBufferCS上传数据。

<center><img src="https://pic1.zhimg.com/80/v2-4479674e726492df52dd59be77504dc5_720w.png" width = "" height = ""></center>


### 3.CullObjectsForShadowCS
这个ComputeShader根据上面ObjectBuffers的包围球以及灯光属性的DFShadow距离做剔除。

把需要绘制DFShadow的Object数据再Copy到另一个RWBuffer CulledObjectData里。

## 修改思路：

1.标记更新（当HISM的剔除结果发生变化）

2.同步剔除数据（Cluster剔除结果存到 Scene->DistanceFieldData）

3.Buffer扩展一个float4，加一个剔除数据(只用到R，GBA后面功能用到)，上传ObjectBufferData（扩展一个Float4）

原本的更新逻辑每次都需要更新19个float4。所以增加一个专门上传剔除数据的ComputeShader，只上传剔除结果float4。

4.剔除阴影绘制的Object（多加一条剔除结果的判断）

5.优化更新的地方：
基于上一帧剔除结果的变化做更新
处理编辑器ClusterTree重建的情况


参考链接：

UHierarchicalInstancedStaticMeshComponent解析
https://blog.csdn.net/qq_29523119/article/details/123932029

UDN社区
https://udn.unrealengine.com/s/question/0D54z00007bzqHWCAY/foliage%E3%81%AB%E8%B7%9D%E9%9B%A2%E6%B6%88%E3%81%97%E3%82%92%E5%85%A5%E3%82%8C%E3%81%9F%E5%A0%B4%E5%90%88distance-field-shadows%E3%81%8C%E6%AE%8B%E3%82%8B%E3%81%AE%E3%82%92%E5%9B%9E%E9%81%BF%E3%81%97%E3%81%9F%E3%81%84

