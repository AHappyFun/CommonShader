---
title: Unity-URP代码架构
date: 2023-02-23
categories:
- Unity
tags:
- Unity
---
本文对URP使用的这段时间的一些理解和总结。从知乎转移：[URP管线架构学习总结](https://zhuanlan.zhihu.com/p/607416554)

## 1.URP渲染管线的架构图

理解一个系统设计比较重要的就是类图了。

<center><img src="https://picx.zhimg.com/80/v2-e1b1b9c396e84afdd8b6bd5aced9c4b0_720w.png?source=d16d100b" width = "" height = ""></center>

## 2.各个类的一些作用和使用
### (1)UniversalRenderPipelineAsset

本质是一个ScriptableObject类型，用于序列化URP的一些设置，General、Quality、Lights、Shadows等。

<!--more-->

### (2)UniversalRenderPipeline

管线的核心类，主要是继承RenderPipeline，并override一个核心Render()方法，渲染摄像机列表。


``` 
protected override void Render(ScriptableRenderContext renderContext, Camera[]cameras)
{
    Render(renderContext, new List<Camera>(cameras));
}
```
假如我们要基于SRP制定管线，也是需要继承RenderPipeline并重写这个方法。

Render()里的主要逻辑就是使用管线的设置一个一个绘制摄像机。

```
protected override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
{
     //1.准备全局设置的数据
     //2.SortCamera摄像机排序
     //3.RenderSingleCamera渲染单个摄像机
}
```

RenderSingleCamera()是设置数据并绘制单个摄像机。
```
public static void RenderSingleCamera(ScriptableRenderContext context, Camera camera)
{
    //1.InitializeCameraData()   使用摄像机上挂的UniversalAdditionalCameraData数据对摄像机设置进行配置
    //2.使用SciptableRenderer进行摄像机绘制，URP里是UniversalRenderer，它继承于ScriptableRenderer。后面有讲解。    
}
```

构造函数UniversalRenderPipeline()使用UniversalRenderPipelineAsset数据进行管线初始化。
```
public UniversalRenderPipeline(UniversalRenderPipelineAsset asset)
{
    //管线的创建
}
```

### (3)UniversalRenderPipelineCore
这个文件比较特殊，里面主要定义了管线需要的数据结构。

RenderData、LightData、CameraData、ShadowData这些数据结构体。

```
    public struct RenderingData
    {
        public CullingResults cullResults;
        public CameraData cameraData;
        public LightData lightData;
        public ShadowData shadowData;
        public PostProcessingData postProcessingData;
        public bool supportsDynamicBatching;
        public PerObjectData perObjectData;

        /// <summary>
        /// True if post-processing effect is enabled while rendering the camera stack.
        /// </summary>
        public bool postProcessingEnabled;
    }
    public struct LightData
    {
        public int mainLightIndex;
        public int additionalLightsCount;
        public int maxPerObjectAdditionalLightsCount;
        public NativeArray<VisibleLight> visibleLights;
        internal NativeArray<int> originalIndices;
        public bool shadeAdditionalLightsPerVertex;
        public bool supportsMixedLighting;
        public bool reflectionProbeBoxProjection;
        public bool reflectionProbeBlending;
        public bool supportsLightLayers;

        /// <summary>
        /// True if additional lights enabled.
        /// </summary>
        public bool supportsAdditionalLights;
    }
    其他结构...
```
ShaderPropertyId定义管线全局需要的Shader内变量PropertyId
```
    internal static class ShaderPropertyId
    {  
        public static readonly int time = Shader.PropertyToID("_Time");
        public static readonly int sinTime = Shader.PropertyToID("_SinTime");
        public static readonly int cosTime = Shader.PropertyToID("_CosTime");
        public static readonly int deltaTime = Shader.PropertyToID("unity_DeltaTime");
        public static readonly int timeParameters = Shader.PropertyToID("_TimeParameters");
        public static readonly int viewMatrix = Shader.PropertyToID("unity_MatrixV");
        public static readonly int projectionMatrix = Shader.PropertyToID("glstate_matrix_projection");
        public static readonly int viewAndProjectionMatrix = Shader.PropertyToID("unity_MatrixVP");
        ...其他
    }
```

ShaderKeywordStrings定义管线的shader关键字
```
    public static class ShaderKeywordStrings
    {
        public static readonly string MainLightShadows = "_MAIN_LIGHT_SHADOWS";
        public static readonly string MainLightShadowCascades = "_MAIN_LIGHT_SHADOWS_CASCADE";
        public static readonly string MainLightShadowScreen = "_MAIN_LIGHT_SHADOWS_SCREEN";
        public static readonly string CastingPunctualLightShadow = "_CASTING_PUNCTUAL_LIGHT_SHADOW"; 
       ...其他
     }
```

### (4)ScriptableRenderPass
这些渲染单元的核心类，我们要实现功能最终就是体现在它上面。

将一个功能的渲染功能进行内聚，最后在上层可以进行自由组合变成不同的Renderer(Forward或Deferred)，这个unity做的很聪明。

常用的属性方法是：
```
    renderPassEvent  //pass的渲染event

    Configure()  //called by the renderer before executing the render pass.

    OnCameraSetup()  //called by the renderer before rendering a camera.

    OnCameraCleanup(CommandBuffer cmd) //Called on finish rendering a camera

    Execute(ScriptableRenderContext context, ref RenderingData renderingData);  //Pass的真正内容

    CreateDrawingSettings()  //创建一个DrawSettings对象，控制一些settings
```

### (5)ScriptableRenderer
这是一个抽象类，目的就是把多个ScriptableRenderPass进行组合，满足不同的情况。
抽象类底层提供了ScriptableRenderFeature的管理支持，以及不管怎么自定义都需要的一些方法。
```
public abstract partial class ScriptableRenderer : IDisposable
{
    设置摄像机矩阵
    void SetCameraMatrices()

    设置每个摄像机的渲染变量，比如worldCameraPos、screenParams、ZBufferParams等
     void SetPerCameraShaderVariables()

     UniversalRenderPipeline绘制摄像机中间去调。执行各个RenderPass的Execute()
     void Execute()

     管理renderfeature的list
     List<ScriptableRenderFeature> renderfeatures

     管理开启的RenderPass队列
     List<ScriptableRenderPass> m_ActiveRenderPassQueue
 
     ...
}
```

### (6)UniversalRenderer
Unity提供一个UniversalRenderer继承于ScriptableRenderer，它将很多很多的Pass功能组合在一起，然后自由配置Pass的执行策略。

内部有个RenderMode可以设置是Forward还是Deferred的渲染路径。

管理了unity自带的一些必要Pass。当然因为继承于ScriptableRenderer，也支持自定义RenderFeature。
```
 public sealed class UniversalRenderer : ScriptableRenderer
{
        DepthOnlyPass m_DepthPrepass;
        DepthNormalOnlyPass m_DepthNormalPrepass;
        CopyDepthPass m_PrimedDepthCopyPass;
        MotionVectorRenderPass m_MotionVectorPass;
        MainLightShadowCasterPass m_MainLightShadowCasterPass;
        AdditionalLightsShadowCasterPass m_AdditionalLightsShadowCasterPass;
        GBufferPass m_GBufferPass;
        CopyDepthPass m_GBufferCopyDepthPass;
        TileDepthRangePass m_TileDepthRangePass;
        TileDepthRangePass m_TileDepthRangeExtraPass; // TODO use subpass API to hide this pass
        DeferredPass m_DeferredPass;
        DrawObjectsPass m_RenderOpaqueForwardOnlyPass;
        DrawObjectsPass m_RenderOpaqueForwardPass;
        DrawSkyboxPass m_DrawSkyboxPass;
        CopyDepthPass m_CopyDepthPass;
        CopyColorPass m_CopyColorPass;
        TransparentSettingsPass m_TransparentSettingsPass;
        DrawObjectsPass m_RenderTransparentForwardPass;
        InvokeOnRenderObjectCallbackPass m_OnRenderObjectCallbackPass;
        FinalBlitPass m_FinalBlitPass;
        CapturePass m_CapturePass;
        ...
}
```

### (7)ScriptableRenderFeature
本质是一个ScriptableObject，它序列化我们自定义RenderPass的设置，并以一个AddRenderPasses将自定义RenderPass添加进pass列表中。

有几个比较重要的需要使用的数据和方法。
```
    IsActive : 控制Feature是否生效

    public abstract  void Create();   //做RenderPass的构造和初始化

    public abstract void AddRenderPasses(ScriptableRenderer renderer, ref RenderingDatarenderingData); // 将RenderPass加入渲染队列
    
    public abstract void OnCameraPreCull(); //在camera剔除之前执行

    Dispose();  //销毁资源
```
本文主要从结构设计的角度分析，所以没有深入到具体方法以及逻辑实现。

祝大家学习快乐。

---

引用参考：

[URP源码学习 https://zhuanlan.zhihu.com/p/153075170](https://zhuanlan.zhihu.com/p/153075170)