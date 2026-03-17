---
title: Unity-GPUDriven草地渲染
date: 2026-03-10
categories:
- Unity
tags:
- Unity
---


记录一下YCT里GPUDriven 草地渲染实现。

## 静态数据烘焙

使用地形Mesh和美术画的草地Mask图，生成草地的数据。

草地数据包含草地的transform数据，以及lightmapUV数据。数据都是依赖地形生成，位置通过地形方格插值，lightmapUV同理。

这样草地就可以采样烘焙的ShadowMask，在树和房子下面的草地有阴影效果更好。

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/6.png?raw=true" width = "" height = ""></center>

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/7.png?raw=true" width = "" height = ""></center>


## GPU数据上传

GrassInfo保存的transformMatrix是地形空间的，在Shader中再从地形转到世界空间计算风的顶点动画。

GPU上存两份GrassInfo的Buffer，一份是所有的Data，一份是剔除后的Data。

## GPU CS剔除

在GPU上进行视锥剔除。

摄像机的Planes和草的AABB进行测试。填充测试通过的草地数据到Buffer。

## PreZ Pass

先进行深度绘制，后面可以利用EarlyZ降低很大的Overdraw。


## GPU DrawIndirect

GPU直接绘制草地。

```
cmd.DrawMeshInstancedIndirect(GrassUtil.unitMesh,0,grassTerrian.material,0,grassTerrian.argsBuffer);
```

