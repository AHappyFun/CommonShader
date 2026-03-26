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

&ensp;&ensp;1.带宽没那么贵

&ensp;&ensp;&ensp;&ensp; GDDR6 / HBM 带宽可以100GB/s

&ensp;&ensp;2.功耗不是第一优先级

TBDR(Arm Mail、PowerVR、高通Adreno、Apple自研)主要用于手机、平板：设计哲学是尽可能避免访问外存VRAM

&ensp;&ensp; 1.带宽非常贵

&ensp;&ensp;&ensp;&ensp; LPDDR5 速度大概 几十GB/s，一次Vram访问 = 几十倍Alu成本

&ensp;&ensp; 2.散热限制

&ensp;&ensp;&ensp;&ensp; 带宽高——>发热——>降频

&ensp;&ensp; 3.电池限制

&ensp;&ensp;&ensp;&ensp; 带宽高——>电量消耗大

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/8.png?raw=true" width = "" height = ""></center>

## IMR

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/9.png?raw=true" width = "" height = ""></center>

## TBR

## TBDR

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/unity-common/10.png?raw=true" width = "" height = ""></center>

