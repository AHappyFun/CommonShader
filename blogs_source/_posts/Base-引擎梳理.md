---
title: Base-引擎梳理
date: 2020-01-02
categories:
- 原理
tags:
- 原理
---

引擎梳理。感谢GPT。

## 一、渲染管线架构（Engine Rendering Architecture）
⭐⭐⭐（非常重要）

这些是现代引擎渲染系统的骨架。

### Frame Graph / Render Graph

RenderGraph

Pass dependency

Resource lifetime

Transient RT

Barrier 自动插入

### GPU Driven Rendering

GPU Scene

Indirect Draw

Instance Culling

Cluster / Meshlet Culling

### Command Buffer / Render Queue

RenderPass scheduling

Async compute

Graphics queue / compute queue

### Resource Management

Render Target Pool

Transient resource

Texture streaming

Virtual Texture

## 二、几何与可见性（Geometry & Visibility）
⭐⭐ ～ ⭐⭐⭐

### 基础

Frustum Culling ⭐

Occlusion Culling ⭐⭐

Hi-Z Buffer ⭐⭐

### 现代 GPU 可见性

Cluster Culling ⭐⭐⭐

Meshlet Rendering ⭐⭐⭐

GPU Driven Pipeline ⭐⭐⭐

### 空间结构

BVH ⭐⭐⭐

Octree ⭐⭐

KD Tree ⭐⭐

### 高级

Nanite-like virtual geometry ⭐⭐⭐⭐

## 三、光照系统（Lighting）
⭐⭐ ～ ⭐⭐⭐

### 传统

Forward Rendering ⭐

Deferred Rendering ⭐

Tiled Lighting ⭐⭐

Clustered Lighting ⭐⭐

### 阴影

Shadow Map ⭐

Cascaded Shadow Map ⭐⭐

Variance Shadow Map ⭐⭐

Moment Shadow Map ⭐⭐

Distance Field Shadow ⭐⭐⭐

Ray traced shadow ⭐⭐⭐

## 四、GI（Global Illumination）
⭐⭐ ～ ⭐⭐⭐⭐

### 传统

Lightmap ⭐

SH Probe ⭐

Light Probe Proxy Volume ⭐⭐

### 实时 GI

Screen Space GI ⭐⭐

DDGI ⭐⭐⭐

SDF GI ⭐⭐⭐

Voxel GI ⭐⭐⭐

ReSTIR GI ⭐⭐⭐⭐

Lumen-like GI ⭐⭐⭐⭐

## 五、Screen Space 技术
⭐⭐

SSAO ⭐⭐

HBAO ⭐⭐

GTAO ⭐⭐⭐

SSR ⭐⭐

SSGI ⭐⭐

Contact Shadow ⭐⭐

## 六、Temporal 技术
⭐⭐⭐

你已经研究：

✔ TAA

但其实这一块有很多。

TAA ⭐⭐⭐

TAAU ⭐⭐⭐

TSR ⭐⭐⭐

DLSS integration ⭐⭐

FSR integration ⭐⭐

Motion Vector ⭐⭐⭐

History rejection ⭐⭐⭐

## 七、体积渲染（Volumetric）
⭐⭐ ～ ⭐⭐⭐

Height Fog ⭐

Volumetric Fog ⭐⭐

Participating Media ⭐⭐⭐

Volumetric Lighting ⭐⭐

Light Scattering ⭐⭐

God Ray ⭐⭐

## 八、距离场 / 体素系统
⭐⭐⭐

你刚开始做 SDF，这块是引擎级技术。

Mesh Distance Field

Global Distance Field

SDF AO

SDF Shadow

Voxelization

Sparse Voxel Octree

## 九、后处理系统
⭐

基础但必须会。

Bloom

Tone Mapping

Color Grading

Depth of Field

Motion Blur

Lens Flare

Chromatic Aberration

## 十、抗锯齿技术
⭐⭐

MSAA

FXAA

SMAA

TAA

TSR

DLSS / FSR integration

## 十一、现代 GPU 技术
⭐⭐⭐

越来越重要。

Compute Shader Pipeline

Async Compute

Wave Intrinsics

GPU Prefix Sum

GPU Sorting

Indirect Dispatch

## 十二、数据压缩 / 纹理系统
⭐⭐

Texture Compression

ASTC / BC

Mipmap Streaming

Virtual Texture

Clipmap

## 十三、粒子系统 / GPU 特效
⭐⭐

GPU Particle

GPU Simulation

Fluid Sim

Niagara-like systems

## 十四、引擎级优化
⭐⭐⭐

真正的工程能力。

Frame Pacing

GPU/CPU sync

Cache friendly layout

Bandwidth optimization

Memory pool

GPU profiler

## 十五、现代引擎的新趋势
⭐⭐⭐⭐

未来几年会越来越重要。

Work Graphs（DX12）

Mesh Shader pipeline

GPU Driven Rendering

Procedural world streaming

Neural rendering




