---
title: Base-TBDR架构
date: 2023-2-19
categories:
- 原理
tags:
- 原理
- 优化
---

## 问题背景

### 为什么直接一条流水线会有性能瓶颈？

在IMR里，GPU流水线是：

提交三角形——>VS——>Raster——>FS——>输出合并

没有全局信息、没有延迟、完全按照顺序执行。

GPU在执行FS的时候，并不知道像素最终是否可见，深度测试太晚，FS已经执行完了。

### 带宽/计算，谁更贵？

GPU硬件关注点不同，诞生的背景。

IMR(Nvidia、AMD)主要用于PC、主机：主要是低延迟、流水线简单、吃计算(浪费一些没事),多算+多访问带宽换取简单和低延迟。

    1.带宽没那么贵

        GDDR6 / HBM 带宽可以100GB/s

    2.功耗不是第一优先级

TBDR(Arm Mail、PowerVR、高通Adreno、Apple自研)主要用于手机、平板：设计哲学是尽可能避免访问外存VRAM

    1.带宽非常贵

        LPDDR5 速度大概 几十GB/s，一次Vram访问 = 几十倍Alu成本

    2.散热限制

        带宽高——>发热——>降频

    3.电池限制

        带宽高——>电量消耗大

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/8.png?raw=true" width = "" height = "300"></center>

## IMR

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/9.png?raw=true" width = "" height = ""></center>

## TBR

Binning阶段和TBDR一样。

TileRendering阶段

     没有HSR。

     没做延迟FS。

总结：做了Tile化，优化了带宽。但是没有像素的可见性剔除，overdraw没解决。所以进化成为TBDR。



## TBDR

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/10.png?raw=true" width = "" height = ""></center>

### 为什么做TBDR？

主要为了带宽优化 + 减少Overdraw。

IMR，每个像素反复读写显存。
TBDR，只在最后一次写显存。

一句话总结就是：TBDR通过tile内计算，把多次显存读写变成一次，节省带宽。

### GEME(片上内存)

    1.Load/Store 

        load : 从显存到Tile

        store : 写回显存

    2.Tile Flush（性能杀手）

    发生在：

        RenderTarget切换，Pass切换，MSAA resolve
这些都是GEME被迫写回了显存，导致带宽问题。

### TBDR的执行流程

第一阶段：Binning分桶

    1.执行VS。得到ClipPos

    2.三角形组装。把顶点拼接成三角形。

    3.裁剪。裁剪视锥外的三角形。

    4.转换到屏幕空间Clip——>NDC——>ScreenSpace

    5.计算屏幕空间BoundingBox包围盒。对每个三角形算出包围盒。

    6.Tile覆盖测试。判断三角形属于哪个Tile。

    7.构建Tile Primitive List。每个Tile有个三角形的list。之后上传到TileBuffer。

第二阶段：TileRendering(片上内存处理OnChip-Memory)

    1.每个Tile有了三角形列表，以及每个三角形的插值数据(uv，normal，color...)

    2.Tile并行处理

    3.先加载Tile到片上内存，GPU在SRAM里创建TileColor[16x16]，TileDepth[16x16]，初始化depth和color

    4.一个Tile为例子，取出Tile的三角形列表，做光栅化。

    5.然后和TileDepth做深度测试(EarlyZ，就是TBDR的HSR)，通过后进行FS

    6.更新TileBuffer的Depth和Color

    7.Tile处理完，写回显存。TileColor——>FrameColor，TileDepth——>FrameDepth。

### TBDR的EarlyZ和传统的EarlyZ的区别？

IMR(Nvidia、AMD)：

    VS——Raster——EarlyZ——FS——LateZTest

    EarlyZ是可选优化。有LateZ兜底。

    失效情况：Discard、AlphaTest、修改深度、Blend

    性能点：EarlyZ不稳定，FS可能重复执行导致OverDraw。

TBDR(ARM Mali/PowerVR)

    VS——Binning——Tile(Raster、HSR、FS)

    EarlyZ(HSR)是固定流程，必须走。没有LateZ兜底。

    失效情况：几乎不会失效。但是AlphaClip会影响优化程度。

### AlphaClip并不会打断HSR，为什么还会影响TBDR性能？

    正常情况：在tile内，先ZTest，确定遮挡可以直接丢弃不跑FS

    AlphaClip情况：不知道遮挡关系了，不知道像素的深度需不需要写入(因为不知道当前情况是不是走Clip)，需要把FS跑完才知道。

    结果：HSR效果下降，不确定像素是否Clip，不能丢弃当前TileBuffer上的值。多跑FS，增加了OverDraw。

### SinglePassFetch

底层机制FrameBuferrFetch：移动端mali和PowerVR里，允许Tile内FS直接读取当前像素的Color结果(Depth一般不允许)。

SPF优化的是：RenderTarget读写带宽、多Pass合并为单Pass多步

    比如后处理合并RenderPass，多个效果叠加一起，只执行一次Pass。

    但是只能优化处理一个像素的算法，需要邻边像素结果的都不行(同Tile的邻边像素也不行)。

    因为FrameBufferFetch带过来的是当前像素的上一个FS的结果，无法获取其他像素的结果。

SinglePassFetch的条件

    1.必须同一个RenderPass内连续执行。
        打断的情况：
            RenderFeature分开执行。
            Blit到RT。
            CopyColor/CopyDepth。

    2.RenderTarget不能变(colorAttachment和depthAttachment)

    3.不能依赖邻边像素(无法利用FrameBufferFetch获取)。SSAO、TAA、半分辨率算法，这些都不行。

### TBDR核心总结

TBDR优化的核心是尽量让渲染过程停留在On-Chip的GMEM中，避免和外部显存交互。

Tile Flush是其中最典型的性能开销，因为它会导致GMEM数据写回显存并可能再次加载。

但本质上从减少Load/Store、降低带宽、以及控制Tile内工作量三个角度来优化。

SubPass、SinglePassFetch这些合并Pass的方式，也是减少Load/Store的次数。

