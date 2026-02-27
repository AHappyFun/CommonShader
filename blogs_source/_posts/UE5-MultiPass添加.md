---
title: UE5-MultiPass添加 # 标题
date: 2024-06-15
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

UE里默认不支持多Pass，项目里一般都会需要这个功能。

记录一下一种实现思路。

效果视频：

<iframe height=600 width=1024 src="https://www.bilibili.com/video/BV1Sf421D7q5">
</iframe>

# StaticMesh多Pass

实现主要是两个方面，一个是材质管理，另一个是把多Pass加入渲染流程中。

## 材质管理

首先需要在UStaticMesh和UStaticMeshComponent里新增多Pass材质。

UStaticMesh是用资产编辑器打开的窗口，最里层的材质设置。

UStaticMeshComponent是SM要渲染的必要组件，可以设置材质进行覆盖UStaticMesh里的材质。(常见里摆放或者蓝图里)

多Pass的结构定义，材质Index以及是否投阴影。

```
//~ StaticMesh的多pass材质结构，选择和FStaticMaterial对应，就不用去对应LOD的各种琐碎问题
USTRUCT(BlueprintType)
struct FStaticMultiMaterial
{
	GENERATED_USTRUCT_BODY()
	
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = StaticMesh)
	TObjectPtr<class UMaterialInterface> MaterialInterface;

	//插槽名字没用
	/*This name should be use by the gameplay to avoid error if the skeletal mesh Materials array topology change*/
	//UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = StaticMesh)
	//FName MaterialSlotName;

	//材质Index，对应原本的材质Index，最好是数量和index一一对应，就可以做到与LOD无关
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = StaticMesh)
	int MaterialIndex;

	//是否CastShadow
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = StaticMesh)
	uint8 bCastShadow : 1;

	FStaticMultiMaterial()
	: MaterialInterface(NULL)
	{
	
	}
	
};
```

在UStaticMesh和UStaticMeshComponent里定义材质列表。

```
----------UStaticMesh里-------------
	//StaticMesh的多pass材质
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = StaticMesh)
	TArray<FStaticMultiMaterial> StaticMultiPassMaterials;
```

```
--------StaticMeshComponent里----------
	//Loy MultiPass MultiPass开关
	UPROPERTY(EditAnywhere, AdvancedDisplay, BlueprintReadWrite, Category = MultiPassMat)
	uint8 bEnableMultiPassMaterial : 1;

	//Loy 是否覆盖StaticMesh原本的多Pass材质
	UPROPERTY(EditAnywhere, AdvancedDisplay, BlueprintReadWrite, Category = MultiPassMat)
	uint8 bOverrideStaticMeshMultiPassMaterial : 1;

	//Loy Override的材质列表
	UPROPERTY(EditAnywhere, AdvancedDisplay, BlueprintReadWrite, Category = MultiPassMat)
	TArray<struct FStaticMultiMaterial> OverrideStaticMultiMaterials;

-----一些Get方法----------
    //loy GetSMMultiPassMats
	const TArray<struct FStaticMultiMaterial> GetStaticMultiPassMaterials() const;
	virtual FStaticMultiMaterial GetMultiPassMaterial(int32 MaterialIndex) const;
	virtual UMaterialInterface* GetEditorMultiPassMaterial(int32 MaterialIndex) const;
```

其中GetMaterial的几个方法里，基本就是按照MaterialIndex来传递材质，首先获取UStaticMesh的，如果StaticMeshComponent Override了，就返回SMComponent里的材质。

## 加入MultiPass

负责StaticMesh渲染的大多在StaticMeshRender里，FStaticMeshSceneProxy在渲染线程里的操作。

需要把多Pass加入到中DrawStaticElements和GetDynamicMeshElements两个方法里。

DrawStaticElements方法通常在SMSceneProxy在加入到场景里的时候调用，或者被移动了造成SceneProxy重新创建的时候调用。
<center><img src="https://picx.zhimg.com/80/v2-15e916cf3e0c973feed915e58d7cf551_720w.png" width = "" height = ""></center>

<center><img src="https://pic1.zhimg.com/80/v2-36f80d0f08fbfdd6f128b69837414d7c_720w.png" width = "" height = ""></center>


GetDynamicMeshElements方法在动态绘制路径。每帧收集MeshBatch的路径，默认SM有这个方法，就加了进去。。

# SkeletalMesh多Pass

蒙皮网格的多pass实现思路和静态的差不多，就是渲染路径只有动态的了。

也是材质管理和插入多pass到收集MeshBatch的地方。

## 材质管理
首先在SkeletalMesh和SkinnedMeshComponent里新增材质列表。

SkeletalMesh就是资源编辑器打开资产的窗口，美术可以预设多pass材质。

SkinnedMeshComponent(继承下去的SkeletalMeshComponent)是场景里渲染SkeletalMesh用，可以设置并覆盖资产的材质列表。

SK多Pass的结构：
```
//SK的多pass材质结构
USTRUCT(BlueprintType)
struct FSkeletalMultiPassMaterial
{
	GENERATED_USTRUCT_BODY()

	//对应主材质的Index，这里不关联Section，因为LOD里Section里有材质index的对应关系
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = SkeletalMesh)
	int32 MaterialIndex;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = SkeletalMesh)
	TObjectPtr<class UMaterialInterface> 	MaterialInterface;
	
};
```

SkeletalMesh里新增材质列表。
```
	//** List of MultiPassMaterials apply to this mesh -Loy */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, duplicatetransient, Category = MultiPassMaterial)
	TArray<FSkeletalMultiPassMaterial> MultiPassMaterials;
```

SkinnedMeshComponent里新增材质列表和覆盖开关。
```
	//是否开启多pass
	UPROPERTY(EditAnywhere, Category = "Materials")
	uint8 bEnableMultiPassMaterial : 1;

	//是否override SK里的多pass材质
	UPROPERTY(EditAnywhere, Category = "Materials")	
	uint8 bOverrideSKMultiPassMaterial : 1;

	UPROPERTY(EditAnywhere, Category = "Materials")
	TArray<FSkeletalMultiPassMaterial> MultiPassMaterials;

------一些Get方法--------
    //Loy MultiPass
	UMaterialInterface* GetMultiPassMaterial(int32 MaterialIndex) const;
	TArray<FSkeletalMultiPassMaterial> GetMultiPassMaterials() const;
	UMaterialInterface* GetOverrideMultiPassMaterial(int32 MaterialIndex) const;
```

## 加入多Pass

因为SKMesh是动态绘制路径，所以就在GetDynamicMeshElements里加入多Pass的MeshBatch。

```
FSkeletalMeshSceneProxy::GetDynamicMeshElements
——————>FSkeletalMeshSceneProxy::GetMeshElementsConditionallySelectable
    {
        		GetDynamicElementsSection(Views, ViewFamily, VisibilityMap, LODData, LODIndex, SectionIndex, bSectionSelected, SectionElementInfo, bInSelectable, Collector);

				//加入多Pass MeshBatch
				if(bEnableMultiPassMaterial)
				{
					FSectionElementInfo MultiPassSectionInfo(nullptr, SectionElementInfo.bEnableShadowCasting, SectionElementInfo.UseMaterialIndex);
					MultiPassSectionInfo.Material = SectionElementInfo.MultiPassMaterial;

					if(MultiPassSectionInfo.Material)
						GetDynamicElementsSection(Views, ViewFamily, VisibilityMap, LODData, LODIndex, SectionIndex, bSectionSelected, MultiPassSectionInfo, false, Collector);
				}

    }
```