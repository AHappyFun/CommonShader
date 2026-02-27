---
title: UE5-自定义MeshComponent # 标题
date: 2023-09-08
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---
虚幻自定义MeshComponent在此总结一下。

基于UE5.1 Github版本

<iframe height=600 width=1024 src="https://www.bilibili.com/video/BV1Nk4y1P7wX?t=0">
</iframe>


# 1.几个比较重要的概念

## UPrimitiveComponent

```
class ENGINE_API UPrimitiveComponent : public USceneComponent, public INavRelevantInterface, public IInterface_AsyncCompilation
{  
};

```

UPrimitiveComponent继承于USceneComponent，所以具有Transform属性和父子嵌套的能力。

UPrimitiveComponent是一切几何组件的父类，比如UE自带的ShapeComponent、StaticMeshComponent、SkeletalMeshComponent等组件追溯上去都是继承UPrimitiveComponent。

UPrimitiveComponent相关内容在渲染线程里非常常见。

<!--more-->

<center><img src="https://picx.zhimg.com/80/v2-1c38f0c0f6c27e3f550e2bc3d921e94b_720w.png" width = "" height = ""></center>

## FPrimitiveSceneProxy

由于虚幻采用的多线程渲染架构，FPrimitiveSceneProxy想当于是UPrimitiveComponent在渲染线程上的体现。

引擎在渲染线程的开始，通过UpdateAllPrimitiveSceneInfos接口，更新UPrimitiveComponent的数据到FPrimitiveSceneProxy。

之后渲染的过程，渲染线程都是使用FPrimitiveSceneProxy的数据。

<center><img src="https://picx.zhimg.com/80/v2-7c66bf3cc394b838ac53288a77551072_720w.png" width = "" height = ""></center>

## UMeshComponent
UMeshComponent是继承UPrimitiveComponent的组件，定义了材质相关的接口。

常见的UStaticMeshComponent和USkinnedMeshComponent直接继承于UMeshComponent。

下面自定义Mesh也是继承于UMeshComponent开始。

## 绘制路径(动静结合)
虚幻引擎设计里有很多动静结合的例子，关于渲染就是把物体分为需要View的静态、完全静态和动态，其中静态物体只有第一次或者标记更新就去更新数据，动态物体每帧都去更新数据。


### 静态物体的更新：

```
FPrimitiveSceneInfo::AddToScene()
    AddStaticMeshes()
        if(bAddToStaticDrawLists)
            CacheMeshDrawCommands() //缓存MeshDrawCommand
```

### 动态物体的更新：

```
FSceneRenderer::ComputeViewVisibility()
    FSceneRenderer::GatherDynamicMeshElements()
        for (int32 PrimitiveIndex = 0; PrimitiveIndex < NumPrimitives; ++PrimitiveIndex)
        {
            //每个SceneInfo收集MeshBatch
            PrimitiveSceneInfo->Proxy->GetDynamicMeshElements(InViewFamily.Views,   InViewFamily, ViewMaskFinal, Collector);
        }   
```

<center><img src="https://pica.zhimg.com/80/v2-816a6e3d7c0d1fc971e5c2e548d00814_720w.png" width = "" height = ""></center>

## FMeshBatch、FMeshBatchElement

FMeshBatchElement主要绑定顶点、三角形IndexBuffer等资源。

FMeshBatch包含了很多FMeshBatchElement，并定义了使用什么材质、什么顶点工厂等。

渲染线程计算可见性的时候，会判断动态物体(Primitive)是否渲染，然后在GetDynamicMeshElements里收集Primitive的MeshBatch。


<center><img src="https://picx.zhimg.com/80/v2-0a548934900472ba3f97ee32acb2e3c9_720w.png" width = "" height = ""></center>



```
FSceneRenderer::GatherDynamicMeshElements（）
{
    //收集每个Primitive的MeshBatch
    for (int32 PrimitiveIndex = 0; PrimitiveIndex < NumPrimitives; ++PrimitiveIndex)
    {
        PrimitiveSceneInfo->Proxy->GetDynamicMeshElements(InViewFamily.Views, InViewFamily, ViewMaskFinal, Collector);
    }

    // Compute DynamicMeshElementsMeshPassRelevance for this primitive.

    //计算动态Mesh相关性，PassMask，即哪些MeshPass会渲染本次MeshBatch
    ComputeDynamicMeshRelevance(ShadingPath, bAddLightmapDensityCommands, ViewRelevance, MeshBatch, View, PassRelevance, PrimitiveSceneInfo, Bounds);
}
```

所以每个FPrimitiveSceneProxy都需要有自己的GetDynamicMeshElements方法。

# 2.自定义MeshComponent

## 新建ULoyCustomMeshComponent

### LoyCustomMeshComponent.h
```
#pragma once

#include "CoreMinimal.h"
#include "UObject/ObjectMacros.h"
#include "Engine/EngineTypes.h"
#include "Components/MeshComponent.h"
#include "LoyCustomMeshComponent.generated.h"

class FPrimitiveSceneProxy;

UCLASS(hidecategories=(Object, Physics, Activation, "Components|Activation"), editinlinenew, meta=(BlueprintSpawnableComponent), ClassGroup=Rendering)
class ENGINE_API ULoyCustomMeshComponent : public UMeshComponent
{
	GENERATED_UCLASS_BODY()

protected:
	//---UActorComponent需要实现的接口---
	virtual void OnRegister() override;
	virtual void OnUnregister() override;
	virtual void TickComponent(float DeltaTime, enum ELevelTick TickType, FActorComponentTickFunction *ThisTickFunction) override;
	virtual void SendRenderDynamicData_Concurrent() override;
	virtual void CreateRenderState_Concurrent(FRegisterComponentContext* Context) override;
	virtual void ApplyWorldOffset(const FVector& InOffset, bool bWorldShift) override;

	//---USceneComponent需要实现的接口---
	//视锥剔除需要的BOX
	virtual FBoxSphereBounds CalcBounds(const FTransform& LocalToWorld) const override;

	//---UPrimitiveComponent需要实现的接口---
	//渲染代理
	virtual  FPrimitiveSceneProxy* CreateSceneProxy() override;

	//---UMeshComponent需要实现的接口 ---
	virtual int32 GetNumMaterials() const override;

	//---自定义Mesh需要的参数---
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="MeshRendering")
	TArray<FVector> Triangles;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="MeshRendering")
	TArray<FVector> PointVectors;
	
private:

	TArray<FVector> Points;

	friend class FLoyCustomMeshSceneProxy;
	
};
```

### LoyCustomMeshComponent.cpp
```

#include "Components/LoyCustomMeshComponent.h"
#include "PrimitiveViewRelevance.h"
#include "PrimitiveSceneProxy.h"
#include "RenderResource.h"
#include "RenderingThread.h"
#include "LocalVertexFactory.h"

//---Index Buffer---
class FLoyCustomMeshIndexBuffer : public FIndexBuffer
{
public:
	virtual void InitRHI() override
	{
		FRHIResourceCreateInfo CreateInfo(TEXT("FLoyCustomMeshIndexBuffer"));
		IndexBufferRHI = RHICreateIndexBuffer(sizeof(int32), NumIndices * sizeof(int32), BUF_Dynamic, CreateInfo);
	}

	int32 NumIndices;
};

struct FLoyCustomMeshDynamicData
{
	TArray<FVector> Points;
	TArray<FVector> Triangles;
};


//---SceneProxy---
class ENGINE_API FLoyCustomMeshSceneProxy final : public FPrimitiveSceneProxy
{

private:
	UMaterialInterface* Material;
	FStaticMeshVertexBuffers VertexBuffers;
	FLoyCustomMeshIndexBuffer IndexBuffer;
	FLocalVertexFactory VertexFactory;

	FLoyCustomMeshDynamicData* DynamicData;

	FMaterialRelevance MaterialRelevance;

	int32 PointNums;
	int32 IndexNums;
	
public:
	
	SIZE_T GetTypeHash() const override
	{
		static size_t UniquePointer;
		return reinterpret_cast<size_t>(&UniquePointer);
	}

	FLoyCustomMeshSceneProxy(ULoyCustomMeshComponent* Component)
		: FPrimitiveSceneProxy(Component)
		, Material(NULL)
		, VertexFactory(GetScene().GetFeatureLevel(), "FLoyCustomMeshSceneProxy")
		, DynamicData(NULL)
		, MaterialRelevance(Component->GetMaterialRelevance(GetScene().GetFeatureLevel()))
		, PointNums(Component->Points.Num())
		, IndexNums(Component->Triangles.Num() * 3)
	{
		//三角形和索引初始化
		VertexBuffers.InitWithDummyData(&VertexFactory, GetVertexCount());
		IndexBuffer.NumIndices = GetIndexCount();
		BeginInitResource(&IndexBuffer);
		
		Material = Component->GetMaterial(0);
		if(Material == NULL)
		{
			Material = UMaterial::GetDefaultMaterial(MD_Surface);
		}
		
		
	}

	virtual ~FLoyCustomMeshSceneProxy()
	{
		VertexBuffers.PositionVertexBuffer.ReleaseResource();
		VertexBuffers.ColorVertexBuffer.ReleaseResource();
		VertexBuffers.StaticMeshVertexBuffer.ReleaseResource();
		IndexBuffer.ReleaseResource();
		VertexFactory.ReleaseResource();
		if(DynamicData != NULL)
		{
			delete DynamicData;
		}
	}

	int32 GetVertexCount() const
	{
		return PointNums;
	}

	int32 GetIndexCount() const
	{
		return IndexNums;
	}

	void BuildCustomMesh(const TArray<FVector>& InPoints, const TArray<FVector>& InTriangeles, TArray<FDynamicMeshVertex>& OutVertices, TArray<int32>& OutIndices)
	{
		const FColor VertexColor(255, 255, 255);
		const int32 NumPoints = InPoints.Num();

		//顶点
		for(int32 VertexID = 0; VertexID < NumPoints; VertexID++)
		{
			FDynamicMeshVertex Vert;
			Vert.Position = (FVector3f)InPoints[VertexID];
			Vert.Color = VertexColor;
			Vert.SetTangents(FVector3f(1, 0, 0), FVector3f(0, 1, 0), FVector3f(0, 0, 1));

			OutVertices.Add(Vert);
		}
		
		//三角形
		for (int32 i = 0; i< InTriangeles.Num(); i++)
		{
			OutIndices.Add((int32)InTriangeles[i].X);
			OutIndices.Add((int32)InTriangeles[i].Y);
			OutIndices.Add((int32)InTriangeles[i].Z);
		}
		
	}

	void SetDynamicData_RenderThread(FLoyCustomMeshDynamicData* NewDynamicData)
	{
		check(IsInRenderingThread());

		// Free existing data if present
		if(DynamicData)
		{
			delete DynamicData;
			DynamicData = NULL;
		}
		DynamicData = NewDynamicData;

		TArray<FDynamicMeshVertex> Vertices;
		TArray<int32> Indices;
		BuildCustomMesh(NewDynamicData->Points, NewDynamicData->Triangles, Vertices, Indices);

		//check(Vertices.Num() == GetVertexCount());
		//check(Indices.Num() == GetIndexCount());

		//顶点传到VertexBuffer
		for (int i = 0; i < Vertices.Num(); i++)
		{
			const FDynamicMeshVertex& Vertex = Vertices[i];

			VertexBuffers.PositionVertexBuffer.VertexPosition(i) = Vertex.Position;
			VertexBuffers.StaticMeshVertexBuffer.SetVertexTangents(i, Vertex.TangentX.ToFVector3f(), Vertex.GetTangentY(), Vertex.TangentZ.ToFVector3f());
			VertexBuffers.StaticMeshVertexBuffer.SetVertexUV(i, 0, Vertex.TextureCoordinate[0]);
			VertexBuffers.ColorVertexBuffer.VertexColor(i) = Vertex.Color;
		}
		
		{
			auto& VertexBuffer = VertexBuffers.PositionVertexBuffer;
			void* VertexBufferData = RHILockVertexBuffer(VertexBuffer.VertexBufferRHI, 0, VertexBuffer.GetNumVertices() * VertexBuffer.GetStride(), RLM_WriteOnly);
			FMemory::Memcpy(VertexBufferData, VertexBuffer.GetVertexData(), VertexBuffer.GetNumVertices() * VertexBuffer.GetStride());
			RHIUnlockVertexBuffer(VertexBuffer.VertexBufferRHI);
		}

		{
			auto& VertexBuffer = VertexBuffers.ColorVertexBuffer;
			void* VertexBufferData = RHILockVertexBuffer(VertexBuffer.VertexBufferRHI, 0, VertexBuffer.GetNumVertices() * VertexBuffer.GetStride(), RLM_WriteOnly);
			FMemory::Memcpy(VertexBufferData, VertexBuffer.GetVertexData(), VertexBuffer.GetNumVertices() * VertexBuffer.GetStride());
			RHIUnlockVertexBuffer(VertexBuffer.VertexBufferRHI);
		}

		{
			auto& VertexBuffer = VertexBuffers.StaticMeshVertexBuffer;
			void* VertexBufferData = RHILockVertexBuffer(VertexBuffer.TangentsVertexBuffer.VertexBufferRHI, 0, VertexBuffer.GetTangentSize(), RLM_WriteOnly);
			FMemory::Memcpy(VertexBufferData, VertexBuffer.GetTangentData(), VertexBuffer.GetTangentSize());
			RHIUnlockVertexBuffer(VertexBuffer.TangentsVertexBuffer.VertexBufferRHI);
		}
		
		{
			auto& VertexBuffer = VertexBuffers.StaticMeshVertexBuffer;
			void* VertexBufferData = RHILockVertexBuffer(VertexBuffer.TexCoordVertexBuffer.VertexBufferRHI, 0, VertexBuffer.GetTexCoordSize(), RLM_WriteOnly);
			FMemory::Memcpy(VertexBufferData, VertexBuffer.GetTexCoordData(), VertexBuffer.GetTexCoordSize());
			RHIUnlockVertexBuffer(VertexBuffer.TexCoordVertexBuffer.VertexBufferRHI);
		}

		//拷贝IndexBuffer
		void* IndexBufferData = RHILockIndexBuffer(IndexBuffer.IndexBufferRHI, 0, Indices.Num() * sizeof(int32), RLM_WriteOnly);
		FMemory::Memcpy(IndexBufferData, &Indices[0], Indices.Num() * sizeof(int32));
		RHIUnlockIndexBuffer(IndexBuffer.IndexBufferRHI);
		
	}

	//收集MeshBatch和MeshElements
	virtual void GetDynamicMeshElements(const TArray<const FSceneView*>& Views, const FSceneViewFamily& ViewFamily, uint32 VisibilityMap, FMeshElementCollector& Collector) const override
	{
		QUICK_SCOPE_CYCLE_COUNTER( STAT_LoyCustomMeshSceneProxy_GetDynamicMeshElements );

		const bool bWireframe = AllowDebugViewmodes() && ViewFamily.EngineShowFlags.Wireframe;

		auto WireframeMaterialInstance = new FColoredMaterialRenderProxy(
			GEngine->WireframeMaterial ? GEngine->WireframeMaterial->GetRenderProxy() : NULL,
			FLinearColor(0, 0.5f, 1.f)
			);

		Collector.RegisterOneFrameMaterialProxy(WireframeMaterialInstance);

		FMaterialRenderProxy* MaterialProxy = NULL;
		if(bWireframe)
		{
			MaterialProxy = WireframeMaterialInstance;
		}
		else
		{
			MaterialProxy = Material->GetRenderProxy();
		}

		for (int32 ViewIndex = 0; ViewIndex < Views.Num(); ViewIndex++)
		{
			if (VisibilityMap & (1 << ViewIndex))
			{
				const FSceneView* View = Views[ViewIndex];

				FMeshBatch& Mesh = Collector.AllocateMesh();
				FMeshBatchElement& BatchElement = Mesh.Elements[0];
				BatchElement.IndexBuffer = &IndexBuffer;
				Mesh.bWireframe = bWireframe;
				Mesh.VertexFactory = &VertexFactory;
				Mesh.MaterialRenderProxy = MaterialProxy;

				bool bHasPrecomputedVolumetricLightmap;
				FMatrix PreviousLocalToWorld;
				int32 SingleCaptureIndex;
				bool bOutputVelocity;
				GetScene().GetPrimitiveUniformShaderParameters_RenderThread(GetPrimitiveSceneInfo(), bHasPrecomputedVolumetricLightmap, PreviousLocalToWorld, SingleCaptureIndex, bOutputVelocity);

				FDynamicPrimitiveUniformBuffer& DynamicPrimitiveUniformBuffer = Collector.AllocateOneFrameResource<FDynamicPrimitiveUniformBuffer>();
				DynamicPrimitiveUniformBuffer.Set(GetLocalToWorld(), PreviousLocalToWorld, GetBounds(), GetLocalBounds(), true, bHasPrecomputedVolumetricLightmap, DrawsVelocity(), bOutputVelocity);
				BatchElement.PrimitiveUniformBufferResource = &DynamicPrimitiveUniformBuffer.UniformBuffer;

				BatchElement.FirstIndex = 0;
				BatchElement.NumPrimitives = GetIndexCount()/3;
				BatchElement.MinVertexIndex = 0;
				BatchElement.MaxVertexIndex = GetVertexCount();
				Mesh.ReverseCulling = IsLocalToWorldDeterminantNegative();
				Mesh.Type = PT_TriangleList;
				Mesh.DepthPriorityGroup = SDPG_World;
				Mesh.bCanApplyViewModeOverrides = false;
				Collector.AddMesh(ViewIndex, Mesh);

#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
				// Render bounds
				RenderBounds(Collector.GetPDI(ViewIndex), ViewFamily.EngineShowFlags, GetBounds(), IsSelected());
#endif
			}
		}
		
	}
	
	virtual FPrimitiveViewRelevance GetViewRelevance(const FSceneView* View) const override
	{
		FPrimitiveViewRelevance Result;
		Result.bDrawRelevance = IsShown(View);
		Result.bShadowRelevance = IsShadowCast(View);
		Result.bDynamicRelevance = true;
		MaterialRelevance.SetPrimitiveViewRelevance(Result);
		return Result;
	}

	virtual uint32 GetMemoryFootprint( void ) const override { return( sizeof( *this ) + GetAllocatedSize() ); }

	uint32 GetAllocatedSize( void ) const { return( FPrimitiveSceneProxy::GetAllocatedSize() ); }
};

//-----------------------------------------------------------//
	
	
ULoyCustomMeshComponent::ULoyCustomMeshComponent(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	UE_LOG(LogTemp, Warning, TEXT("Loy Ctor"));
	
	PrimaryComponentTick.bCanEverTick = true;
	bTickInEditor = true;
	bAutoActivate = true;

	PointVectors.AddUninitialized(3);
	Triangles.AddUninitialized(1);

	SetCollisionProfileName(UCollisionProfile::PhysicsActor_ProfileName);
}
	
FPrimitiveSceneProxy* ULoyCustomMeshComponent::CreateSceneProxy()
{
	UE_LOG(LogTemp, Warning, TEXT("Loy CreateSceneProxy"));
	return new FLoyCustomMeshSceneProxy(this);
}

int32 ULoyCustomMeshComponent::GetNumMaterials() const
{
	return 1;
}

void ULoyCustomMeshComponent::OnRegister()
{
	Super::OnRegister();
	
	UE_LOG(LogTemp, Warning, TEXT("Loy OnRegister"));
	
	Points.Reset();
	Points.Append(PointVectors);
}

void ULoyCustomMeshComponent::OnUnregister()
{
	Super::OnUnregister();

	UE_LOG(LogTemp, Warning, TEXT("Loy OnUnRegister"));
}

void ULoyCustomMeshComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	MarkRenderDynamicDataDirty();
}

void ULoyCustomMeshComponent::CreateRenderState_Concurrent(FRegisterComponentContext* Context)
{
	Super::CreateRenderState_Concurrent(Context);

	UE_LOG(LogTemp, Warning, TEXT("Loy CreateRenderState_Concurrent"));

	SendRenderDynamicData_Concurrent();
}

void ULoyCustomMeshComponent::ApplyWorldOffset(const FVector& InOffset, bool bWorldShift)
{
	Super::ApplyWorldOffset(InOffset, bWorldShift);

	UE_LOG(LogTemp, Warning, TEXT("Loy ApplyWorldOffset"));

	for (FVector& P : Points)
	{
		P += InOffset;
	}
}

void ULoyCustomMeshComponent::SendRenderDynamicData_Concurrent()
{
	if(SceneProxy)
	{

		UE_LOG(LogTemp, Warning, TEXT("Loy SendRenderDynamicData_Concurrent"));
		
		FLoyCustomMeshDynamicData* DynamicData = new FLoyCustomMeshDynamicData;

		//world to local
		const FTransform& ComponentTransform = GetComponentTransform();

		int32 NumPoints = Points.Num();
		DynamicData->Points.AddUninitialized(NumPoints);
		for (int32 PointId = 0; PointId < Points.Num(); PointId++)
		{
			//这里传模型坐标
			DynamicData->Points[PointId] = Points[PointId];
		}

		int32 NumIndexs = Triangles.Num();
		DynamicData->Triangles.AddUninitialized(NumIndexs);
		
		for (int32 i = 0; i < Triangles.Num(); i++)
		{
			DynamicData->Triangles[i] = Triangles[i];
		}
		

		//send to render thread
		FLoyCustomMeshSceneProxy* Proxy = (FLoyCustomMeshSceneProxy*)SceneProxy;
		ENQUEUE_RENDER_COMMAND(FSendCableDynamicData)(
			[Proxy, DynamicData](FRHICommandListImmediate& RHICmdList)
		{
			Proxy->SetDynamicData_RenderThread(DynamicData);
		});
	}
}

FBoxSphereBounds ULoyCustomMeshComponent::CalcBounds(const FTransform& LocalToWorld) const
{
	UE_LOG(LogTemp, Warning, TEXT("Loy CalcBounds"));
	
	//构建包围盒
	FBox MeshBox(ForceInit);
	float MinX = 0, MinY = 0, MinZ = 0;
	float MaxX = 0, MaxY = 0, MaxZ = 0;
	for (int32 i = 0; i < Points.Num(); i++)
	{
		FVector p = LocalToWorld.TransformPosition(Points[i]);
		if(i == 0)
		{
			MinX = p.X;
			MaxX = p.X;
			MinY = p.Y;
			MaxY = p.Y;
			MinZ = p.Z;
			MaxZ = p.Z;
			continue;
		}
		MinX = FMath::Min(MinX, p.X);
		MinY = FMath::Min(MinY, p.Y);
		MinZ = FMath::Min(MinZ, p.Z);
		MaxX = FMath::Max(MaxX, p.X);
		MaxY = FMath::Max(MaxY, p.Y);
		MaxZ = FMath::Max(MaxZ, p.Z);
	}
	MeshBox.Min = FVector(MinX, MinY, MinZ);
	MeshBox.Max = FVector(MaxX, MaxY, MaxZ);
	
	return FBoxSphereBounds(MeshBox);
}

```