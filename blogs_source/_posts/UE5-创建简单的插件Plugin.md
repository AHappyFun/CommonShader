---
title: UE5-创建简单的插件Plugin # 标题
date: 2023-09-11
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---
虚幻创建插件在此总结一下。

基于UE5.1 Github版本

## 在项目里创建插件

<center><img src="https://pica.zhimg.com/80/v2-54bde048aecbdd4b712f90605bccdfae_720w.png" width = "" height = ""></center>

有一个.Build.cs文件，一个插件Module的Plugin.cpp文件。

<!--more-->

<center><img src="https://pic1.zhimg.com/80/v2-0cd74cb49a573e229f284c64424cc418_720w.png" width = "" height = ""></center>


## 将自定义Mesh组件转换为插件

LoyCustomMeshComponent.Build.cs 插件模块Build依赖项
```
using UnrealBuildTool;

public class LoyCustomMeshComponent : ModuleRules
{
	public LoyCustomMeshComponent(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;
		
		PrivateDependencyModuleNames.Add("LoyCustomMeshComponent");
		
		PublicDependencyModuleNames.AddRange(
			new string[]
			{
				"Core",
				"CoreUObject",
				"Engine",
				"RenderCore",
				"RHI"
			}
		);
	}
}
```

LoyCustomMeshComponentPlugin.cpp 定义插件Module
```
#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

class FLoyCustomMeshComponentModule : public IModuleInterface
{
public:

	/** IModuleInterface implementation */
	void StartupModule()
	{
	}
	
	void ShutdownModule()
	{
	}
	
};

#define LOCTEXT_NAMESPACE "FLoyCustomMeshComponentModule"
#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FLoyCustomMeshComponentModule, LoyCustomMeshComponent)
```
