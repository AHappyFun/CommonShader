---
title: Base-阴影ShadowMap相关
date: 2024-05-29
categories:
- 原理
tags:
- 原理
---

这篇记一下ShadowMap阴影的技术。

# 1.ShadowMap相关

## ShadowMap的原理

从Light的方向渲染场景的深度图，因为具有遮挡关系，所以能做阴影用。https://zhuanlan.zhihu.com/p/384446688

<center><img src="https://pic3.zhimg.com/v2-a3e308678f94fbaf22642116039d4ff6_r.jpg" width = "" height = "400"></center>


## 阴影投影的过程

需要投影的物体的转换过程，从Light方向画这些物体的深度：

World空间——

——>Light空间  先位移，再旋转

——>Light视锥体 (XY范围缩放，Z深度缩放) 范围-1~1

——>ShadowMap(CascadeTile划分，像素Border)


## 阴影的一些问题和解决办法

### --Bias和阴影尖刺--

有DepthBias和NormalBias两种Bias，用来解决阴影尖刺问题。

在采样ShadowMap的时候，应用NormalBias，WorldPos往法线方向偏一些。

DepthBias则是直接修改灯光深度偏移。

阴影尖刺：
<center><img src="https://pic1.zhimg.com/v2-bfc175687011fe28af22c162f3d22608.png" width = "" height = "200"></center>

应用NormalBias，在表面往法线方向Bias：
<center><img src="https://picx.zhimg.com/80/v2-d2ad03b2bc89f748bcf7b4f5b0081fdb_720w.png" width = "" height = "200"></center>


### --阴影平坠问题--

防止阴影在近裁剪之前被裁剪的技术，只能用于平行光（正交投影）。
<center><img src="https://pic1.zhimg.com/80/v2-1176d90f395600c516488893f92ebdcc_720w.png" width = "" height = "500"></center>


### --Border--

因为有时候ShadowMap是一整个大ShadowMap。

为了防止边界被用串了，一般边界空出几个像素是空的。

### --抗锯齿--

阴影的锯齿一般都很严重，需要使用抗锯齿来软化一下。

一般使用PCF算法。


# 2.CSM阴影

## Cascade的划分

参考大佬文章：
https://zhuanlan.zhihu.com/p/379042993/

网上一个Cascade划分的办法，Light视锥体刚好包住每个Camera分段。https://blog.csdn.net/qq_39300235/article/details/107765941

<center><img src="https://pic1.zhimg.com/80/v2-b0d407b6867ffd4bb8622c228668e7d3_720w.png" width = "" height = "300"></center>

UE4里我看是把视锥分为几个段，通过每段Camera视锥的八个点先计算出一个包围球。

划分规则:在DirLightComponent上有个参数CascadeDistributionExponent控制指数系数，举个例子3级联 指数是3

第一级Cascade的范围：[near, near + 1/13 * (far - near)]

第二级Cascade的范围：[near + 1/13 * (far - near), near + 4/13 * (far - near)]

第三级Cascade的范围：[near + 4/13 * (far - near), far]

<center><img src="https://pica.zhimg.com/80/v2-856c6cb71db81b2b1f3291eca4b84562_720w.png" width = "" height = "300"></center>


然后包围球再计算出一个BoundBox，然后每段得到一个Light的视锥体。具体划分代码在GetShadowSplitBounds，大概如下：

<center><img src="https://pic1.zhimg.com/80/v2-18b6b41f18d6c9658c619696f8193d57_720w.gif" width = "" height = "400"></center>

## CSM的矩阵

CSM的矩阵和普通的平行光阴影差不多，就是上面的划分部分各不相同，主要是确定LightFrustum的XYZ缩放。

右乘的矩阵为：

CSM的WorldToShadowMapMatrix = TranslationMatrix(移到视锥段中心) * RotateMatrix(旋转到Light方向) * ScaleMatrix(XY缩放为LightFrustum范围确定，Z缩放一般定义一个深度范围再映射到01) * 分Tile缩放和Offset，移动到ShadowMap分块的中心

UE里的Forward阴影矩阵代码（WorldToShadowMartix）：

```
//比如3级Cascade 一个Tile 2048  ，大ShadowMap是6144x2048。实际每个Tile只画2040x2040，边界留4个像素。
//1 / 6144
const float InvBufferResolutionX = 1.0f / (float)ShadowBufferResolution.X;
//0.5 * 2040 * 1 / 6144
const float ShadowResolutionFractionX = 0.5f * (float)ResolutionX * InvBufferResolutionX;
//1 / 2048
const float InvBufferResolutionY = 1.0f / (float)ShadowBufferResolution.Y;
//0.5 * 2040 * 1 / 2048   
const float ShadowResolutionFractionY = 0.5f * (float)ResolutionY * InvBufferResolutionY;

//上面可以算出来0级在ShadowMap的所在UV中心

const FMatrix WorldToShadowMatrix =
// Translate to the origin of the shadow's translated world space
FTranslationMatrix(PreShadowTranslation) *
// Transform into the shadow's post projection space
// This has to be the same transform used to render the shadow depths
SubjectAndReceiverMatrix *
// Scale and translate x and y to be texture coordinates into the ShadowInfo's rectangle in the shadow depth buffer
// Normalize z by MaxSubjectDepth, as was done when writing shadow depths
FMatrix(
    FPlane(ShadowResolutionFractionX,0,                            0,                                    0),
    FPlane(0,                         -ShadowResolutionFractionY,0,                                    0),
    FPlane(0,                        0,                            InvMaxSubjectDepth,    0),
    FPlane(
        (X + BorderSize) * InvBufferResolutionX + ShadowResolutionFractionX,  //第一级CasadeX偏移就是(2048 + 4) * 1 / 6144 + 0级在ShadowMap的所在UV.X
        (Y + BorderSize) * InvBufferResolutionY + ShadowResolutionFractionY,  //第一级CasadeY偏移就是(0 + 4) * 1 / 2048 + 0级在ShadowMap的所在UV.Y
        0,
        1
    )
);

```
UE还有个延迟渲染使用屏幕空间阴影的版本（ScreenToShadowMatrix）：

ScreenToShadow = ScreenToWorld * WorldToShadow
```
FMatrix FProjectedShadowInfo::GetScreenToShadowMatrix(const FSceneView& View, uint32 TileOffsetX, uint32 TileOffsetY, uint32 TileResolutionX, uint32 TileResolutionY) const
{
	const FIntPoint ShadowBufferResolution = GetShadowBufferResolution();
	const float InvBufferResolutionX = 1.0f / (float)ShadowBufferResolution.X;
	const float ShadowResolutionFractionX = 0.5f * (float)TileResolutionX * InvBufferResolutionX;
	const float InvBufferResolutionY = 1.0f / (float)ShadowBufferResolution.Y;
	const float ShadowResolutionFractionY = 0.5f * (float)TileResolutionY * InvBufferResolutionY;
	// Calculate the matrix to transform a screenspace position into shadow map space

	FMatrix ScreenToShadow;
	FMatrix ViewDependentTransform =
		// Z of the position being transformed is actually view space Z, 
			// Transform it into post projection space by applying the projection matrix,
			// Which is the required space before applying View.InvTranslatedViewProjectionMatrix
		FMatrix(
			FPlane(1,0,0,0),
			FPlane(0,1,0,0),
			FPlane(0,0,View.ViewMatrices.GetProjectionMatrix().M[2][2],1),
			FPlane(0,0,View.ViewMatrices.GetProjectionMatrix().M[3][2],0)) *
		// Transform the post projection space position into translated world space
		// Translated world space is normal world space translated to the view's origin, 
		// Which prevents floating point imprecision far from the world origin.
		View.ViewMatrices.GetInvTranslatedViewProjectionMatrix() *
		FTranslationMatrix(-View.ViewMatrices.GetPreViewTranslation());

	FMatrix ShadowMapDependentTransform =
		// Translate to the origin of the shadow's translated world space
		FTranslationMatrix(PreShadowTranslation) *
		// Transform into the shadow's post projection space
		// This has to be the same transform used to render the shadow depths
		FMatrix(TranslatedWorldToClipInnerMatrix) *
		// Scale and translate x and y to be texture coordinates into the ShadowInfo's rectangle in the shadow depth buffer
		// Normalize z by MaxSubjectDepth, as was done when writing shadow depths
		FMatrix(
			FPlane(ShadowResolutionFractionX,0,							0,									0),
			FPlane(0,						 -ShadowResolutionFractionY,0,									0),
			FPlane(0,						0,							InvMaxSubjectDepth,	0),
			FPlane(
				(TileOffsetX + BorderSize) * InvBufferResolutionX + ShadowResolutionFractionX,
				(TileOffsetY + BorderSize) * InvBufferResolutionY + ShadowResolutionFractionY,
				0,
				1
				)
			);

	if (View.bIsMobileMultiViewEnabled && View.Family->Views.Num() > 0)
	{
		// In Multiview, we split ViewDependentTransform out into ViewUniformShaderParameters.MobileMultiviewShadowTransform
		// So we can multiply it later in shader.
		ScreenToShadow = ShadowMapDependentTransform;
	}
	else
	{
		ScreenToShadow = ViewDependentTransform * ShadowMapDependentTransform;
	}
	return ScreenToShadow;
}
```

## 哪些物体需要投射阴影？阴影裁剪剔除问题

//todo CSM的裁剪逻辑


## 阴影采样哪一级Cascade？

接下来的问题是采样的时候，当前WorldPos采样哪一级Cascade。方法应该也有很多种。

<center><img src="https://pic1.zhimg.com/v2-e31657a844ca2af3ea9a6a2f86308554_r.jpg" width = "" height = "400"></center>

1.在Unity里，SRP里当时写的根据WorldPos到周围BoundSphere球心的距离进行选择，如果同时在两个中间，采样两次，进行混合。

计算处于哪个Cascade。

```
	MyShadowData data;
	data.shadowMask.distance = false;
	data.shadowMask.shadows = 1.0;
	data.shadowMask.always = false;
	data.cascadeBlend = 1.0;
	//最大距离之外无阴影,做渐变
	//这个距离衰减基于视角空间，作为3种阴影的全局衰减
	data.strength = FadeShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
	int i = 0;
	//计算出应该采样哪一级cascade，最后i就是级联层级
	for(i = 0; i< _CascadeCount; i++){
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz); 
		//平方对比
		if(distanceSqr < sphere.w){
			float fade = FadeShadowStrength(
				distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z
			);
			
			if(i == _CascadeCount - 1)
			{
				data.strength *= fade;   //最大距离的
			}
			else
			{
				data.cascadeBlend = fade; //级联的Fade
			}
			break;
		}
	}
```
采样的时候发现如果有CascadeBlend就会采样两次进行混合。
<center><img src="https://picx.zhimg.com/80/v2-bb19d11ac630d0a7ace9157acf94d408_720w.png" width = "" height = "400"></center>


2.在UE里直接转换WholeSceneShadowMap转换为ShadowMaskTexture

<center><img src="https://picx.zhimg.com/80/v2-6e08e8011cb08f9afb8c6ff24db6f617_720w.png" width = "" height = "600"></center>

每个Cascade转换一次，转换到屏幕空间。
<center><img src="https://picx.zhimg.com/80/v2-53f813d36790baa6e897dab1219c0605_720w.png" width = "" height = "400"></center>



# 3.PointLight和SpotLight的阴影

一般PointLight和SpotLight的阴影被划分到Other类别里，在美术制作流程里需要控制他们的数量。

在一些地方，点光源和聚光灯的阴影做效果还是必不可少的。

一般申请额外的ShadowMap，放Other类别的阴影，分成Tile，SpotLight占一格，PointLight占6格(这就能看出来点光源阴影比较费了)。

不同点：PointLight和SpotLight都是有位置和范围的，平行光没位置和范围(所以需要阴影范围)

点光源：往6个方向投射阴影，相当于整了个深度的CubeMap。

SpotLight:投影矩阵相对平行光变成了透视矩阵，NormalBias也需要动态计算。

具体细节先不写了...在SRP教程里有： 

https://catlikecoding.com/unity/tutorials/custom-srp/point-and-spot-lights/

# 4.PerObjectShadow

如果角色等需要高精度的阴影，使用CSM有时候不太行。可以使用PerObjectShadow。

PerObjectShadow就是按照角色的BoundBox大小，构建一个光的视锥体。在这个锥体里投射比如512或者1024分辨率的阴影，多个PerObjectShadow可以画在一张大ShadowMap上。

在UE里，通过开启DynamicInsetShadow来应用PerObjectShadow。

1.先画高精度ShadowMapAtlas
<center><img src="https://pic1.zhimg.com/80/v2-2c4b753b20202e3967a23772f2c41f74_720w.png" width = "" height = "400"></center>

2.Light阶段转换合并到屏幕空间阴影
<center><img src="https://pic1.zhimg.com/80/v2-ff1cb5ba812fd7218090c5e45ab34c26_720w.png" width = "" height = "500"></center>
