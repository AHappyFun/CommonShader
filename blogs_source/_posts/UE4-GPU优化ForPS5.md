---
title: UE4-GPU优化RazorForPS5 # 标题
date: 2023-09-18
categories: # 分类
- Unreal
tags: # 标签
- Unreal 
- 优化
---

连接到PS5之后，可以通过Razor GPU For PS5，截帧分析每个DrawCall的具体消耗。

### 1.打开RazorGPUForPS5，点击Capture——GPU Capture截帧

这个工具截出来没有RenderDoc那样对Pass做分类，所以需要上下判断一下当前是哪个阶段（PrePass、BasePass等）

!!!!在截帧之前执行一下命令行profilegpu再截帧，就可以看到Pass分类了!!!


<center><img src="https://picx.zhimg.com/80/v2-10c84155e0280de7e1c2425e5c81e251_720w.png" width = "" height = ""></center>


### 2.点击Capture——ConnectReplay

如果不连接Replay就无法像RenderDoc那样看到当前RT绘制了什么，只能看到RT的最终结果

### 3.点击Capture——GPU Trace，选择VS PS分析

G8-VS PS Bottleneck Analysis

之后就可以看到DrawCall的耗时(单位微秒)，VS PS耗时(ms)以及使用的Cycles。

然后，保存一下截帧文件！！不然切换DrawCall的时候很容易和PS5断开连接。

上下对比查看可以知道本次DrawCall画了什么，发现耗时高的物体从而进一步优化。


<center><img src="https://pic1.zhimg.com/80/v2-964ef8dd99ea88fae8857ee35a553f28_720w.png" width = "" height = ""></center>