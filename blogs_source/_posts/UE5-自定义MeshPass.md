---
title: UE5-自定义MeshPass # 标题
date: 2023-09-11
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---
虚幻自定义MeshPass在此总结一下。

基于UE5.1 Github版本

UE5 AddOutlinePass

https://zhuanlan.zhihu.com/p/597864516

UE4 AddOutlinePass 材质实例参数

https://zhuanlan.zhihu.com/p/576774695

<iframe height=600 width=1024 src="https://www.bilibili.com/video/BV13j411Z7KP">
</iframe>

## OutlinePass的加入

### 1.需要创建一个FToonOutlineMeshPassProcessor继承FMeshPassProcessor

需要实现的方法：

构造函数：初始化PassProcessorRenderState，深度、模板、Blend的模式

AddMeshBatch: 获取到FMeshBatch的顶点工厂、获取Shader、最终BuildMeshDrawCommands

CreateToonOutlinePassProcessor的相关方法，用宏注册方法

外部调用RenderPass的入口，RenderOutlinePass

### 2.创建OutlineShader相关 

需要创建的结构：

VS和PS的C++结构

VS和PS的申明和注册

VS和PS的 usf文件

### 3.SceneVisibility里设置MeshPass的相关性，让Pass生效起来

### 4.在渲染管线中的合适位置，调用自己Pass的Render入口（使用RenderGraph）

### 5.坑：UE5的MeshPass的数量使用了bit5已经32，所以要加新的要改成Bit6，还涉及一些代码

### 6.材质编辑器上加Outline的开关

### 7.材质编辑器自定义参数加入，颜色和float，材质实例的面板override