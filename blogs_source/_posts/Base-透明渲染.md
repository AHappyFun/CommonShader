---
title: Base-透明渲染
date: 2020-07-31
categories:
- 原理
tags:
- 原理
---

其实渲染里没有真正的透明物体，透明效果是通过颜色的Blend模仿到的。

正常的透明渲染需要一个一个前后混合，所以半透明是通过前向渲染。

## 透明的渲染

### 混合指令

Blend   原因子   目标因子

Blend   原RGB因子   目标RGB因子   原A因子    目标A因子

通过不同的混合组合，就可以达到各种效果。

如常见的：

Blend ScrAlpha OneMinusSrcAlpha   //Transparent

Blend One One  //Aditive

Blend ScrAlpha One //Fade


### 渲染顺序

#### Unity的渲染顺序

1.先绘制所有不透明的物体。从前到后。

2.不透明后处理。

3.天空盒。

4.对所有透明的物体排序。

5.按顺序绘制所有透明的物体。从后到前。

6.所有的后处理。

Unity里通过RenderQueue的序列来排序渲染顺序，默认Transparent为3000。

### 透明排序

因为半透明是颜色混合的，两个半透明如果重叠上了，那他们的混合顺序是很重要的，效果也不一样。

透明排序是Unity里常见比较难解决的问题，Unity通过Object到Camera的距离进行排序，在某些情况会出现透明排序出错。

UE的透明暂时还没研究排序。//todo



## OIT顺序无关性透明

### Unity里OIT

#### 1.计算Accumulate

把颜色根据权重叠加到一张图里。

```
Blend ONE ONE

float w(float z, float alpha)
{
    return pow(z, -2.5);   //深度越大，权重值越小
}

float3 C = (ambient + diffuse) * alpha;

#ifdef _WEIGHTED_ON
   return float4(C, alpha) * w(i.z, alpha);
#else
   return float4(C, alpha);
#endif
```

#### 2.计算Revealage

叠加的过程是：

 firstBlend = 0 * srcalpha + (1 - srcalpha) *  dstAlpha 

 secBlend =(1 - srcalpha) *  firstBlend

```
Blend Zero OneMinusSrcAlpha

return albedo.a;
```

#### 3.最终Blend

```
//不透明
fixed4 background = tex2D(_MainTex, i.uv);
//透明颜色累计
float4 accum = tex2D(_AccumTex, i.uv);
//最上层的透明alpha
float revealage = tex2D(_RevealageTex, i.uv).r;

//透明颜色一层
fixed4 col = float4(accum.rgb / clamp(accum.a, 1e-4, 5e4), revealage);

//混合透明与不透明
return (1.0 - col.a) * col + col.a * background;
```


## AlphaTest or Mask模拟透明

在UE里经常有使用Mask再加TAA模拟透明的情况。