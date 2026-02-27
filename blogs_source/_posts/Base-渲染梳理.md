---
title: Base-渲染梳理
date: 2020-01-01
categories:
- 原理
tags:
- 原理
---

渲染梳理目录。

一个游戏的整个渲染都有哪些部分？

## Lighting直接光照

### ForwardRender前向渲染

#### Forward+

#### ClusterForward+

### DeferredRender延迟渲染

#### TileBaseDeferred

#### ClusterDeferred

#### VisibilityBufferDeferred

### ShadingModel光照模型

#### PBR

#### Kajiya

#### 各种CustomShadingModel

## Shadow直接光阴影

### CascadeShadowMap级联阴影

### PerObjectShadow高精度阴影

### DistanceFieldShadow距离场阴影

### ContactShadow接触阴影

### VSM虚拟阴影

### VolumeShadow

### PlanarShadow平面阴影

### 软阴影

#### PCSS

#### PCF

#### VSSM

#### MSM

## GI间接光照

### LightMap

### PRT LightProbe LPPV IrrianceVolume

### LumenGI

### IBL

### LPV

### VXGI

### RayTraceGI

### SSGI

## AO环境光遮蔽

### SSAO

### GTAO

### DFAO

### HBAO

### CapluseAO

## 反射

### CubeMap HDRI

### PlanarReflect平面反射

### SSR

### LumenReflect

## 半透明

### AlphaBlend

### OIT

## 体积氛围渲染

### 体积云、片云

### 体积雾、高度雾

## 水

### 湖水

### 海水

## 特效VFX

### Niagara

### CascadePS

### UnityPS

### UnityVFXGraph

## 毛发渲染

## 贴花Decal

## 抗锯齿AA

### FXAA

### SMAA

### MSAA

### SSAA

### TAA

### TSR

### FSR

## 后处理

### Bloom

### DOF

### Lensflare

### ColorGrading

### ToneMapping