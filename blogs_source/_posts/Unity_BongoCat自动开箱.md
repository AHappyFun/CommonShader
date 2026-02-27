---
title: Unity-BongoCat自动开箱
date: 2026-01-30
categories:
- Unity
tags:
- Unity 
- Client
---

记录BongoCat的自动开箱。

BongoCat的dll没有加密混淆，作者也说代码可见，可以自己修改。

使用反编译工具dnSpy，打开游戏目录的Assembly-CSharp.dll。

然后修改dll里对应的代码。

修改完保存dll替换。

### 1.点击倍数

Pet类里，找到AddPet方法，修改点击数据。

每次点击计数+100
``` 
this._currentGained += 100;
this._currentAchievement += 100;

```
<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/common/2.png?raw=true" width = "" height = ""></center>


### 2.自动开箱

找到Shop类的TimerUpdate()方法。

加入自动开箱代码。

```

if(steamItemDetails_t.m_unQuantity == 0)
{
    this.StockRefreshTimeLeft = 60;
}
else
{
    //xxxxx一堆原来的

    //加入
    this._shopItem.Buy();
}

```

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/common/1.png?raw=true" width = "" height = ""></center>

### 3.开箱时间

修改Shop类成员_stockRefreshTime， 默认是1800秒，半小时。

<center><img src="https://github.com/AHappyFun/CommonShader/blob/master/show/common/3.png?raw=true" width = "" height = ""></center>

时间按自己想要的来，但是游戏有服务器箱子时间，所以开的快也无济于事。