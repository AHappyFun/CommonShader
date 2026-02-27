---
title: UE5-自定义ShadingModel # 标题
date: 2023-09-10
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---
虚幻自定义ShadingModel在此总结一下。

基于UE5.1 Github版本

<center><img src="https://picx.zhimg.com/80/v2-3d2cb99116c988282408787bfae9ce62_720w.png" width = "" height = ""></center>

# 什么是ShadingModel？

在UE的材质编辑器里，材质有ShadingModel可以选择，基本上有Unlit、DefalutLit、Subsurface、ClearCoat、Hair等可以选择。

在BasePass画GBuffer的时候，会把像素的ShadingModelID记到GBuffer里。

在后续光照的时候，ShadingModels.ush的IntegrateBxDF()，根据不同的ShadingModel，得出不一样的FDirectLighting BRDF结果。 

<!--more-->

```
struct FDirectLighting
{
	float3	Diffuse;
	float3	Specular;
	float3	Transmission;
};

FDirectLighting IntegrateBxDF( FGBufferData GBuffer, half3 N, half3 V, half3 L, float Falloff, half NoL, FAreaLight AreaLight, FShadowTerms Shadow )
{
	switch( GBuffer.ShadingModelID )
	{
		case SHADINGMODELID_DEFAULT_LIT:
		case SHADINGMODELID_SINGLELAYERWATER:
		case SHADINGMODELID_THIN_TRANSLUCENT:
			return DefaultLitBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_SUBSURFACE:
			return SubsurfaceBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_PREINTEGRATED_SKIN:
			return PreintegratedSkinBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_CLEAR_COAT:
			return ClearCoatBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_SUBSURFACE_PROFILE:
			return SubsurfaceProfileBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_TWOSIDED_FOLIAGE:
			return TwoSidedBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_HAIR:
			return HairBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_CLOTH:
			return ClothBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_EYE:
			return EyeBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_TOON:
			return ToonBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		default:
			return (FDirectLighting)0;
	}
}

```

# UE5增加ShadingModel

### 在下面文件里新增ShadingModel的定义
EngineTypes.h

BasePassCommon.ush

ClusteredDeferredShadingPixelShader.ush

DeferredShadingModel.ush

Definitions.ush

ShadingCommon.ush

MaterialShader.cpp



### GBuffer里可以添加新ShadingModel需要的额外参数CustomData
MaterialShared.cpp
```
	case MP_CustomData0:	
		CustomPinNames.Add({MSM_ClearCoat, "Clear Coat" });
		CustomPinNames.Add({MSM_Hair, "Backlit"});
		CustomPinNames.Add({MSM_Cloth, "Cloth"});
		CustomPinNames.Add({MSM_Eye, "Iris Mask"});
		CustomPinNames.Add({MSM_SubsurfaceProfile, "Curvature" });
		CustomPinNames.Add({MSM_TOON, "Specular Range" });
		return FText::FromString(GetPinNameFromShadingModelField(Material->GetShadingModels(), CustomPinNames, "Custom Data 0"));
	case MP_CustomData1:
		CustomPinNames.Add({MSM_ClearCoat, "Clear Coat Roughness" });
		CustomPinNames.Add({MSM_Eye, "Iris Distance"});
		CustomPinNames.Add({MSM_TOON, "Offset" });
		return FText::FromString(GetPinNameFromShadingModelField(Material->GetShadingModels(), CustomPinNames, "Custom Data 1"));
```

Material.cpp
```
		case MP_CustomData0:
			Active = ShadingModels.HasAnyShadingModel({ MSM_ClearCoat, MSM_Hair, MSM_Cloth, MSM_Eye, MSM_SubsurfaceProfile });
			Active = ShadingModels.HasAnyShadingModel({ MSM_ClearCoat, MSM_Hair, MSM_Cloth, MSM_Eye, MSM_SubsurfaceProfile, MSM_TOON });
			break;
		case MP_CustomData1:
			Active = ShadingModels.HasAnyShadingModel({ MSM_ClearCoat, MSM_Eye });
			Active = ShadingModels.HasAnyShadingModel({ MSM_ClearCoat, MSM_Eye, MSM_TOON });
			break;
```

ShadingModelsMaterial.ush
```
#if MATERIAL_SHADINGMODEL_TOON
	else if (ShadingModel == SHADINGMODELID_TOON)
	{
		GBuffer.CustomData.r = saturate( GetMaterialCustomData0(MaterialParameters) );	// Specular range
		GBuffer.CustomData.g = saturate( GetMaterialCustomData1(MaterialParameters) );	// offset
	}
#endif
```
ShaderMaterialDerivedHelpers.cpp
```
	Dst.WRITES_CUSTOMDATA_TO_GBUFFER = (Dst.USES_GBUFFER && (Mat.MATERIAL_SHADINGMODEL_SUBSURFACE || Mat.MATERIAL_SHADINGMODEL_PREINTEGRATED_SKIN || Mat.MATERIAL_SHADINGMODEL_SUBSURFACE_PROFILE || Mat.MATERIAL_SHADINGMODEL_CLEAR_COAT || Mat.MATERIAL_SHADINGMODEL_TWOSIDED_FOLIAGE || Mat.MATERIAL_SHADINGMODEL_HAIR || Mat.MATERIAL_SHADINGMODEL_CLOTH || Mat.MATERIAL_SHADINGMODEL_EYE || Mat.MATERIAL_SHADINGMODEL_TOON));
```

### 新增ShadingModel的Brdf函数

```
//loy toon bxdf
float3 ToonStep(float feather, float halfLambert, float threshold = 0.5f)
{
	return smoothstep(threshold - feather, threshold + feather, halfLambert);
}

FDirectLighting ToonBxDF(FGBufferData GBuffer, half3 N, half3 V, half3 L, float Falloff, float NoL, FAreaLight AreaLight, FShadowTerms Shadow)
{
	#if GBUFFER_HAS_TANGENT
		half3 X = GBuffer.WorldTangent;
		half3 Y = normalize(cross(N, X));
	#else
		half3 X = 0;
	half3 Y = 0;
	#endif
		
	BxDFContext Context;
	Init(Context, N, X, Y, V, L);
	SphereMaxNoH(Context, AreaLight.SphereSinAlpha, true);
	Context.NoV = saturate(abs(Context.NoV) + 1e-5);
	
	float SpecularOffset = 0.5;
	float SpecularRange = GBuffer.CustomData.x;
	
	float3 ShadowColor = 0;
		
	ShadowColor = GBuffer.DiffuseColor * ShadowColor;
	float offset = GBuffer.CustomData.y;
	float SoftScatterStrength = 0;
	
	offset = offset * 2 - 1;
	half3 H = normalize(V + L);
	float NoH = saturate(dot(N, H));
	NoL = (dot(N, L) + 1) / 2; // overwrite NoL to get more range out of it
	half NoLOffset = saturate(NoL + offset);
		
	FDirectLighting Lighting;
	Lighting.Diffuse = AreaLight.FalloffColor * (smoothstep(0, 1, NoLOffset) * Falloff) * Diffuse_Lambert(GBuffer.DiffuseColor) * 2.2;
	
	float InScatter = pow(saturate(dot(L, -V)), 12) * lerp(3, .1f, 1);
	float NormalContribution = saturate(dot(N, H));
	float BackScatter = GBuffer.GBufferAO * NormalContribution / (PI * 2);
	
	Lighting.Specular = ToonStep(SpecularRange, (saturate(D_GGX(SpecularOffset, NoH)))) * (AreaLight.FalloffColor * GBuffer.SpecularColor * Falloff * 8);
	
	float3 TransmissionSoft = AreaLight.FalloffColor * (Falloff * lerp(BackScatter, 1, InScatter)) * ShadowColor * SoftScatterStrength;
	float3 ShadowLightener = (saturate(smoothstep(0, 1, saturate(1 - NoLOffset))) * ShadowColor * 0.1);
		
	Lighting.Transmission = (ShadowLightener + TransmissionSoft) * Falloff;
	return Lighting;
}

FDirectLighting IntegrateBxDF( FGBufferData GBuffer, half3 N, half3 V, half3 L, float Falloff, half NoL, FAreaLight AreaLight, FShadowTerms Shadow )
{
	switch( GBuffer.ShadingModelID )
	{
		case SHADINGMODELID_DEFAULT_LIT:
		case SHADINGMODELID_SINGLELAYERWATER:
		case SHADINGMODELID_THIN_TRANSLUCENT:
			return DefaultLitBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_SUBSURFACE:
			return SubsurfaceBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_PREINTEGRATED_SKIN:
			return PreintegratedSkinBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_CLEAR_COAT:
			return ClearCoatBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_SUBSURFACE_PROFILE:
			return SubsurfaceProfileBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_TWOSIDED_FOLIAGE:
			return TwoSidedBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_HAIR:
			return HairBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_CLOTH:
			return ClothBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_EYE:
			return EyeBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		case SHADINGMODELID_TOON:
			return ToonBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		default:
			return (FDirectLighting)0;
	}
}
```

