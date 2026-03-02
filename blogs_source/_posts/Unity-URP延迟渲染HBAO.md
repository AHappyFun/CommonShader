---
title: Unity-URP延迟渲染HBAO
date: 2026-02-10
categories:
- Unity
tags:
- Unity
---

SSAO的进化版。

不再是通过对比深度来判断是否遮挡，而是寻找每个方向上的地平线高度。

## 原理

### 基础

GI是一个几何点从旁边所有角度的光照和。
HBAO就是从几何点往旁边和方向去计算遮蔽的过程，通过简化方向为8个或者16个，结果贴合GI的原理。

从一个几何点，往周围若干个方向打射线，找到每个方向的最大遮挡高度的角度。

下图中，S0、S1、S2、S3是4个方向的射线，分别会得到一个最大的水平角。
方向越容易被遮挡——>水平角越大——>AO越强

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/1.png?raw=true" width = "" height = ""></center>

### 如何计算水平角？

1.计算坡度Slope

坡度 = 高度变化 / 水平变化
tanAngle = 红色 / 蓝色
红色 = 当前射线深度Z - 原始深度Z
蓝色 = 两个平面空间点的距离。length(当前射线点.xy - 原始点.xy)

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/2.png?raw=true" width = "" height = ""></center>

所以角度就是arctan(红色蓝色)

### 如何计算AO贡献？

水平角越大，AO越大。
0到90度的范围，AO遮蔽贡献转换到0到1。
在考虑一下背面的三角形，和法线做一下Dot，调整一下AO值。

最后合计的时候平均一下，

这个几何点的AO = 所有方向的AO加起来 / 方向数量。

## 优化项


### 双边滤波模糊
考虑深度的模糊，避免因为像素算法影响到旁边正常的几何。

### 降分辨率计算
一个点需要几十上百次采样，非常耗费性能。
通常只渲染半分辨率的HBAO。

### HIZ优化步数采样
HIZ


