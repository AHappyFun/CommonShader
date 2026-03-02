---
title: Unity-URP延迟渲染SSR
date: 2026-02-10
categories:
- Unity
tags:
- Unity
---

## 原理

### 基础

SSR需要ColorTexture和DepthTexture。

视角空间的SSR的大概步骤：
1、屏幕空间坐标——>ViewPos
2、ViewPos获取ViewDir和ViewNormal
3、ViewDir和ViewNormal算出视角的反射方向
4、从ViewPos开始RayMarch，方向是反射方向，逐步RayMarch判断深度差(小于Thickness为击中)，判定成功获取到那个地方的ViewPos，转换为屏幕空间坐标返回
5、屏幕空间坐标采样Color图，得到反射颜色

### 代码思路

## 优化项

### HIZ加速
通过生成梯度深度图，加速射线检测区间的判定。
每次从最小的mip开始，如果不合格直接跳过，节省资源。逐次增大mip，缩小射线击中的区间。
到最后得到一个击中点，如果判定是厚度小于阈值(算在表面上)，就继续二分查找精细化。反之，算为没命中。

### Jitter-Dither
优化1. 根据粗糙度和随机，调整RayMarch的步长，减少实际步数。
优化2. 加一个Halftone的偏移，类似TAA。

### 步进数量优化
步进数量是Raymarch算法最需要优化的地方。
1.动态步长。近处密度高，步长小。远处密度低，步长大。
2.分层HIZ检测。mip越细，步长再往里缩小。
3.二分搜索。
4.粗糙度控制步进Scale。
5.重要性Mask。只在符合条件的像素进行RayMarch。

### 二分精度优化
在HIZ或者普通的Raymarch判定击中表面时，按步数前进的那个RayPos可能并没有那么精准。
所以在RayPos的基础上，从两侧进行二分逼近，得到更精确的RayPos。

### 高斯模糊
原始的SSR结果图看起来会有噪点，而且太瑞，不润。模糊一下整体会好很多。
可以根据粗糙度进行调整模糊范围，越粗糙模糊半径越大。

### 基于粗糙度模拟
基于物理直觉的原理：
在微表面理论（Microfacet Theory）里：
- 表面由很多微小镜面组成；
- 每个微面反射方向略有偏差；
- 粗糙度越大，反射方向分布越宽；
- 因此，反射结果越模糊。
SSR里，通过模糊、抖动、多采样来表达这种效果。
1.采样模糊。模糊的时候，粗糙度越大，模糊半径越大。
2.反射抖动。随机扰动模拟微面模型，在射线方向引入随机偏移。多帧之后平均化就呈现模糊反射。
3.Mip模糊+Roughness混合。混合SSR时，不同粗糙度采样不同的Mip。


### TAA抗闪烁
SSR算完之后可以设置一张HistoryTex，做一下TAA。
可以有效减少光爆点和闪烁的情况。

### DDA空间射线
视角空间采样会有下图的问题。

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/3.png?raw=true" width = "" height = ""></center>

所以衍生出DDA屏幕空间RayMarch：
屏幕空间RayMarch，就需要用到画线算法，从一个点到另一个点，之间有一条格子路。
并且，步进的时候，有斜率的问题。比如X是平均1步，Y的步进每次就会不太一样。
DDA画线算法，从A步进到B。

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/4.png?raw=true" width = "" height = ""></center>

屏幕空间步进的优势就是比较均匀，比如Q0到Q1,3d步进后面就会跳跃很大，投影到屏幕步进，就会比较均匀。

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/5.png?raw=true" width = "" height = ""></center>