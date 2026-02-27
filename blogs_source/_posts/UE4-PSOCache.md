---
title: UE4-PSOCache # 标题
date: 2024-05-11
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

### 1.什么是PSO?

PSO(Pipeline State Object)是现代图形API(DX12、Vulkan、Metal)提出的新概念，以前的API设置VS、Rasterizer、PS、BlendState这些状态时，需要一个一个调用设置，PSO可以理解就是把这些状态封装为一个Object，一次调用SetPipelineState的API即可。

### 2.为什么需要Cache PSO？

游戏在运行过程中，根据底层API，会有需要创建新的PSO对象的时候，这个创建的过程比较耗时，会导致卡顿。
PSO Cache就是把游戏中要用到的PSO记下来，然后在游戏引擎初始化阶段直接创建，避免之后的卡顿，所以总的创建时间是一样的，只不过提前了。

stat pipelinecache可以看pso的状态，下图情况就是pso全部是cache预创建的，没有新生成的。

<center><img src="https://picx.zhimg.com/80/v2-8e87e4366a61edadba9c017178f8887c_720w.png" width = "" height = ""></center>

### 3.PSOCache的收集过程

简单来说步骤就是：

1.打包生成两个.shk文件(每次cook产生最新的shk)

2.运行时生成.rec.pipelinecache文件(每次运行产生新的文件，这个就是跑图需要收集的PSOCache文件)

3.将两种文件合并为.stablepc.csv文件用于下一次打包

4.下次打包过程中生成.stabe.upipelinecache文件到包内

5.游戏开始时加载.stable.upipelinecache初始化加载PSO

<center><img src="https://pica.zhimg.com/80/v2-2530cb74bd4ec1416be6c8b17243b9dd_720w.png" width = "" height = ""></center>

### 4.增量收集PSO
知道了收集的过程，可以把出包、跑图生成文件、合并文件这些步骤做成自动化。

如何做增量收集？

保留每次的stablepc.csv文件，最后一起放在Build/Windows/PipelineCaches下，会进行合并。

<center><img src="https://pic1.zhimg.com/80/v2-7731ec4b82d1d8725a9ddffea0555f40_720w.png" width = "" height = ""></center>

代码在UCookOnTheFlyServer::CreatePipelineCache里，读取多个.stable.csv，文件命名有严格要求。

<center><img src="https://pic1.zhimg.com/80/v2-6b5bfa12521ed73b51ecee07621ee98e_720w.png" width = "" height = ""></center>


这样可以多个.stable.csv

<center><img src="https://picx.zhimg.com/80/v2-774f0c0586509627f199de96e28ff65c_720w.png" width = "" height = ""></center>