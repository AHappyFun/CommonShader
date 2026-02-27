---
title: UE4-添加GlobalShader # 标题
date: 2024-05-23
categories: # 分类
- Unreal
tags: # 标签
- Unreal
---

已经在UE4.27 添加了

有两种，

一种是蓝图调用的GlobalShader Draw调用。

另一种是渲染线程过程中加了一步，可以做个类似后处理的那种。

记录第一种蓝图调用的这种，需要的所有东西：

## 1.C++的Shader结构

Shader的声明，对应usf里的文件和方法，shader本身的参数定义

```
//--------------VertexShader-------------------
class FLoyGlobalShaderVS : public FGlobalShader
{
    DECLARE_SHADER_TYPE(FLoyGlobalShaderVS, Global);

public:
    FLoyGlobalShaderVS(){}

    FLoyGlobalShaderVS(const ShaderMetaType::CompiledShaderInitializerType& Initializer)
        :FGlobalShader(Initializer)
    {
        
    }
    
};

IMPLEMENT_SHADER_TYPE(, FLoyGlobalShaderVS, TEXT("/Plugin/LoyCustomGlobalShader/Private/DrawColorShader.usf"), TEXT("MainVS"), SF_Vertex);

//-------------PixelShader-----------------------
class FLoyGlobalShaderPS : public FGlobalShader
{
    DECLARE_SHADER_TYPE(FLoyGlobalShaderPS, Global);
public:
    FLoyGlobalShaderPS(){}

    FLoyGlobalShaderPS(const ShaderMetaType::CompiledShaderInitializerType& Initializer)
    :FGlobalShader(Initializer)
    {
        SimpleColor.Bind(Initializer.ParameterMap, TEXT("SimpleColor"));
        MyTexture.Bind(Initializer.ParameterMap, TEXT("MyTexture"));
        MyTextureSampler.Bind(Initializer.ParameterMap, TEXT("MyTextureSampler"));
    }

    //定义Shader参数
    LAYOUT_FIELD(FShaderParameter, SimpleColor);
    LAYOUT_FIELD(FShaderResourceParameter, MyTexture);
    LAYOUT_FIELD(FShaderResourceParameter, MyTextureSampler);

    //
};

IMPLEMENT_SHADER_TYPE(, FLoyGlobalShaderPS, TEXT("/Plugin/LoyCustomGlobalShader/Private/DrawColorShader.usf"), TEXT("MainPS"), SF_Pixel);
```

## 2.顶点结构和顶点布局
顶点着色器需要用到的顶点布局，Attribute 。 VertexBuffer的布局。

```
//------------------Struct Need------------------------

struct FTextureVertex
{
    FVector4    Position;
    FVector2D    UV;
};

//往Attribute传输的数据
class FMyTextureVertexDeclaration : public FRenderResource
{
public:

    FVertexDeclarationRHIRef VertexDeclarationRHI;

    virtual void InitRHI() override
    {
        FVertexDeclarationElementList Elements;
        uint16 Stride = sizeof( FTextureVertex );
        Elements.Add(FVertexElement(0, STRUCT_OFFSET(FTextureVertex, Position), VET_Float4, 0, Stride));
        Elements.Add(FVertexElement(0, STRUCT_OFFSET(FTextureVertex, UV), VET_Float2, 1, Stride));
        VertexDeclarationRHI = PipelineStateCache::GetOrCreateVertexDeclaration(Elements);
    }

    virtual void ReleaseRHI() override
    {
        VertexDeclarationRHI.SafeRelease();
    }
};
```

## 3.usf 的Shader

```
float4 SimpleColor;

Texture2D MyTexture;
SamplerState MyTextureSampler;

void MainVS(
    in float4 InPosition : ATTRIBUTE0,
    in float2 InUV : ATTRIBUTE1,
    out float2 OutUV : TEXCOORD0,
    out float4 OutClipPos : SV_POSITION)
{
    OutClipPos = InPosition;
    OutUV = InUV;
}

void MainPS(
    in float2 UV : TEXCOORD0,
    out float4 OutColor : SV_Target0)
{
    OutColor = float4(MyTexture.Sample(MyTextureSampler, UV.xy).rgb, 1.0f);
    OutColor *= FLoyGlobalShaderUniform.UniformColor;
    //OutColor = float4(UV, 0.0f, 1.0f);
}

```

## 4.渲染线程的调用接口

PSO的状态绑定，有顶点布局

```
        //PipelineState
        FGraphicsPipelineStateInitializer PSO;
        RHICmdList.ApplyCachedRenderTargets(PSO);
        PSO.DepthStencilState = TStaticDepthStencilState<false, CF_Always>::GetRHI();
        PSO.BlendState = TStaticBlendState<>::GetRHI();
        PSO.RasterizerState = TStaticRasterizerState<>::GetRHI();
        PSO.PrimitiveType = PT_TriangleList;
        PSO.BoundShaderState.VertexDeclarationRHI = VertexDeclaration.VertexDeclarationRHI;
        PSO.BoundShaderState.VertexShaderRHI = VertexShader.GetVertexShader();
        PSO.BoundShaderState.PixelShaderRHI = PixelShader.GetPixelShader();
        SetGraphicsPipelineState(RHICmdList, PSO);
```

VertexBuffer绑定

//RHILockVertexBuffer是DirectX中的函数，用于锁定顶点缓冲区，以便在CPU上直接访问并修改其中的数据。这样的操作允许在CPU上修改顶点数据，然后在需要时将其传输到GPU上进行渲染。

```
    FRHIResourceCreateInfo CreateInfo;
    FVertexBufferRHIRef VertexBufferRHI = RHICreateVertexBuffer(sizeof(FTextureVertex) * 4, BUF_Volatile, CreateInfo);
    void* VoidPtr = RHILockVertexBuffer(VertexBufferRHI, 0, sizeof(FTextureVertex) * 4, RLM_WriteOnly);

//CPU上修改VertexBuffer数据
        FTextureVertex* Vertices = (FTextureVertex*)VoidPtr;
        Vertices[0].Position = FVector4(1.0f, 1.0f, 0, 1.0f);
        Vertices[1].Position = FVector4(-1.0f, 1.0f, 0, 1.0f);
        Vertices[2].Position = FVector4(1.0f, -1.0f, 0, 1.0f);
        Vertices[3].Position = FVector4(-1.0f, -1.0f, 0, 1.0f);
        Vertices[0].UV = FVector2D(1.0f, 1.0f);
        Vertices[1].UV = FVector2D(0.0f, 1.0f);
        Vertices[2].UV = FVector2D(1.0f, 0.0f);
        Vertices[3].UV = FVector2D(0.0f, 0.0f);

//UnlockBuffer ,用于解锁先前使用RHILockVertexBuffer函数锁定的顶点缓冲区，以便将其重新提交给GPU进行渲染。
        RHIUnlockVertexBuffer(VertexBufferRHI);

//设置VertexBuffer
    RHICmdList.SetStreamSource(0, VertexBufferRHI, 0);

//IndexBuffer的绑定
    //IndexBuffer写入
        const TArray<uint32> Indices = {1, 3, 2, 0, 1, 2};
        FRHIResourceCreateInfo IndexCreateInfo;
        FIndexBufferRHIRef IndexBufferRHI = RHICreateIndexBuffer(sizeof(uint32), Indices.Num() * sizeof(uint32), BUF_Static, IndexCreateInfo);

    //拷贝IndexBuffer，还是先lock，然后CPU修改，再unlock
        void* IndexBufferData = RHILockIndexBuffer(IndexBufferRHI, 0, Indices.Num() * sizeof(uint32), RLM_WriteOnly);
        FMemory::Memcpy(IndexBufferData, &Indices[0], Indices.Num() * sizeof(uint32));
        RHIUnlockIndexBuffer(IndexBufferRHI);

//DrawCall的时候绑定IndexBuffer
        RHICmdList.DrawIndexedPrimitive(IndexBufferRHI, 0, 0, Indices.Num(), 0, Indices.Num() / 3, 1);
```

## 5.其他
资源转换

//旧
RHICmdList.TransitionResource

//新
RHICmdList.Transition()
