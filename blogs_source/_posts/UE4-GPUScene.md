---
title: UE4-GPUScene # 标题
date: 2023-09-14
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

UE4里GPUScene相关的梳理。

# 1.引擎传输Primitive数据到GPU的方式

什么是PrimitiveData?

PrimitiveData是UPrimitiveComponent级别的几何数据，包括LocalToWorldMatrix，WorldPosition，AABB，LightMap等数据。

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/UE-common/1.png?raw=true" width = "" height = ""></center>


## 传统方式

每个Primitive一个UniformBuffer，每次DrawCall绑定。


```
GameThread

→ FPrimitiveSceneProxy

→ CreatePrimitiveUniformBufferImmediate()

→ RHICreateUniformBuffer

→ Draw 时 SetUniformBuffer

→ GPU
```

每一帧每一个Primitve需要，创建，更新，绑定。适合小场景。

每一帧上传：DrawCall * PrimitiveData

如果场景全部是动态物体，这种是合理的。但是现实有大量静态物体的数据，也需要每帧上传。

## GPUScene的方式

为了减少Cpu per-draw state的绑定成本，UE4.23引入了GPUScene。

所有的Primitive数据，打包进一个大的StructuredBuffer，GPU里通过PrimitiveId获取。

然后每一帧不变的静态物体的数据就保持不变，只更新变化的静态物体以及动态物体。

动态物体也分为每个视图(不是全部更新)，视图会提前收集到需要更新的动态物体。

每一帧上传：变化的Static + View * View收集的Dynamic

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/UE-common/2.png?raw=true" width = "" height = ""></center>


# 2.GPUScene的工作流程


GPUScene是一个大的功能，它是Primitive基础数据的容器，有一些功能比如DistanceField、LightMap、InstanceCulling这些，有自己的更新逻辑。

如距离场数据的更新，以前在这里写过

https://ahappyfun.github.io/2023/09/04/UE4-HISM%E5%89%94%E9%99%A4%E6%9B%B4%E6%96%B0DFShadow/

### GPUScene基础的更新流程

标脏 → 收集 Dirty Primitive → 构建 PrimitiveShaderData → 批量写入 StructuredBuffer → Shader 通过 PrimitiveId 读取

更新标记Dirty路径：GameThread——>RenderThread

```
UPrimitiveComponent::MarkRenderTransformDirty()
UPrimitiveComponent::MarkRenderStateDirty()

——>

FScene::UpdatePrimitiveTransform()
FScene::UpdatePrimitiveSceneInfo()

——>

Scene->GPUScene.MarkPrimitiveDirty(PrimitiveSceneInfo);

——>

DirtyPrimitiveSceneInfos.Add(PrimitiveSceneInfo);

Dirty标记完成。不立刻更新，后面统一更新。

```

GPU更新流程：

```
FSceneRender::Render()
FSceneRenderer::UpdateGPUScene()

——>

统计Dirty数量
NumDirtyPrimitives = GPUScene.DirtyPrimitiveSceneInfos.Num();

——>

为上传准备CPU Staging buffer
TArray<FPrimitiveSceneShaderData> PrimitiveUploadData;

——>

构建每个 Dirty Primitive 的 ShaderData
for (PrimitiveSceneInfo : DirtyList)
{
    BuildPrimitiveShaderData(...)
}

——>

写入上传数据

——>

批量更新Buffer到GPU
RHICmdList.UpdateBuffer(
    PrimitiveBuffer,
    OffsetInBytes,
    SizeInBytes,
    UploadDataPtr
);


——>

GPU里StructuredBuffer已经更新，shader里获取新的。
PrimitiveSceneData = PrimitiveSceneDataBuffer[PrimitiveId];

```