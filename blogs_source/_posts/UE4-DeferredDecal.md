---
title: UE4-DeferredDecal # 标题
date: 2024-06-05
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

大佬们的文章链接参考：

https://zhuanlan.zhihu.com/p/666213716

https://zhuanlan.zhihu.com/p/100748588

## UE的DeferredDecal

UE的延迟贴花有两种版本，一种是使用DBuffer，还有一种不使用DBuffer。

### 不使用DBuffer的情况
---

首先有一个BOX来划定范围，投射方向。

过程中画两次这个BOX。

第一次，关闭Cull，画Stencil：

<center><img src="https://pic1.zhimg.com/80/v2-d07278d315fe3e309020ce8437f7f6b9_720w.png" width = "" height = "500"></center>

第二次，CullBack，模板测试等于：

<center><img src="https://picx.zhimg.com/80/v2-0546ba0637551da9117749bf929ecfeb_720w.png" width = "" height = "200"></center>

BOX的范围内，深度图转换为WorldPos，然后再转换到BOX空间。

使用BOX内的空间坐标采样Decal图，然后加到Gbuffer里。
<center><img src="https://pica.zhimg.com/80/v2-1fee235ebc662752643c66239f5309c9_720w.png" width = "" height = "250"></center>


如果Decal需要光照后面就也可以计算实时光照，但是无法计算BakeLight，因为BakeLight是在BasePass里画Gbuffer的时候已经算完了。

### 使用DBuffer的情况
---

将Decal的数据画进DBuffer里。

然后在BasePass的时候，把Debuffer融合到GBuffer里，这种情况就支持烘焙光。

<center><img src="https://picx.zhimg.com/80/v2-cb085449e2668e5634c1db5496252b41_720w.png" width = "" height = "600"></center>
