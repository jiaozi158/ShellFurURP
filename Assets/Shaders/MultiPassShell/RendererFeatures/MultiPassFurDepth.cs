using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Reflection;

[DisallowMultipleRendererFeature("Multi-Pass Fur Depth")]
[Tooltip("Add this Renderer Feature to automatically support DepthPrepass for Multi-Pass Fur.")]
public class MultiPassFurDepth : ScriptableRendererFeature
{
    [System.Serializable]
    public class FilterSettings
    {
        public LayerMask LayerMask = 1;
        public string[] PassNames;

        public FilterSettings()
        {
            LayerMask = ~0;
            PassNames = new string[] { "UniversalForwardFur", "DepthOnlyFur", "DepthNormalsFur", "ShadowCasterFur", "UniversalGBufferFur" };
        }
    }
    
    [System.Serializable]
    public class PassSettings
    {
        [HideInInspector] public string passTag = "Fur DepthOnly";
        [Header("Keep It The Same For All")]
        [Tooltip("Controls the number of fur layers. Keep it the same in all Multi-Pass Fur Renderer Features.")]
        // Increase the range if you need more layers.
        [Range(1, 200)]public int ShellAmount = 13;

        // Remove the "[HideInInspector]" if you want to change the RenderPassEvent.
        [Header("Advanced")]
        [Tooltip("Controls when to enqueue the fur DepthPrepass rendering. (After Rendering Pre Passes by default)")]
        [HideInInspector] public RenderPassEvent PassEvent = RenderPassEvent.AfterRenderingPrePasses;

        [HideInInspector] public FilterSettings filterSettings = new FilterSettings();
    }

    // C# Reflection
    private readonly static FieldInfo gBufferFieldInfo = typeof(UniversalRenderer).GetField("m_GBufferPass", BindingFlags.NonPublic | BindingFlags.Instance);
    private readonly static FieldInfo activeRenderPassQueueFieldInfo = typeof(ScriptableRenderer).GetField("m_ActiveRenderPassQueue", BindingFlags.NonPublic | BindingFlags.Instance);
    // For setting RenderTarget use. (unnecessary in URP 12 and below)
#if UNITY_2022_1_OR_NEWER
    private readonly static FieldInfo depthAttachmentFieldInfo = typeof(UniversalRenderer).GetField("m_CameraDepthAttachment", BindingFlags.NonPublic | BindingFlags.Instance);
    private readonly static FieldInfo depthTextureFieldInfo = typeof(UniversalRenderer).GetField("m_DepthTexture", BindingFlags.NonPublic | BindingFlags.Instance);
#endif

    public class FurRenderPass : ScriptableRenderPass
    {
        string m_ProfilerTag;
        private PassSettings settings;
        public List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();
        private FilteringSettings filter;

        public FurRenderPass(PassSettings setting, FilterSettings filterSettings)
        {
            m_ProfilerTag = setting.passTag;
            string[] shaderTags = filterSettings.PassNames;
            this.settings = setting;

            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = 2000;
            queue.upperBound = 3000;
            filter = new FilteringSettings(queue, filterSettings.LayerMask);
            if (shaderTags != null && shaderTags.Length > 0)
            {
                foreach (var passName in shaderTags)
                    m_ShaderTagIdList.Add(new ShaderTagId(passName));
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Fur uses Alpha Test for Transparency.
            SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;

            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

            DrawingSettings depthDrawingSettings = CreateDrawingSettings(m_ShaderTagIdList[1], ref renderingData, sortingCriteria);

            cmd.SetGlobalFloat("_TOTAL_LAYER", settings.ShellAmount);
            for (int i = 0; i < settings.ShellAmount; i++)
            {
                cmd.SetGlobalFloat("_CURRENT_LAYER", i);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                context.DrawRenderers(renderingData.cullResults, ref depthDrawingSettings, ref filter);
            }

            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // We can set render target directly by providing name in URP 12 and below. (No need reflection)
            var renderer = renderingData.cameraData.renderer as UniversalRenderer;
#if UNITY_2022_1_OR_NEWER
            var depthAttachmentHandle = depthAttachmentFieldInfo.GetValue(renderer) as RTHandle;
            var depthTextureHandle = depthTextureFieldInfo.GetValue(renderer) as RTHandle;
#endif

#if UNITY_ANDROID || UNITY_IOS || UNITY_TVOS
            bool m_DepthPrimingRecommended = false;
#else
            bool m_DepthPrimingRecommended = true;
#endif
            // The actual Depth Priming mode.
            bool useDepthPriming = (m_DepthPrimingRecommended && renderer.depthPrimingMode == DepthPrimingMode.Auto) || (renderer.depthPrimingMode == DepthPrimingMode.Forced);

#if UNITY_2022_1_OR_NEWER
            if (useDepthPriming && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth) && depthAttachmentHandle != null)
                ConfigureTarget(depthAttachmentHandle);
            else
                ConfigureTarget(depthTextureHandle);
#else
            if (useDepthPriming && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth))
                ConfigureTarget(renderingData.cameraData.renderer.cameraDepthTarget);
            else
                ConfigureTarget("_CameraDepthTexture");
#endif
        }
    }

    public PassSettings settings = new PassSettings();
    FurRenderPass m_FurRenderPass;
    public override void Create()
    {
        FilterSettings filter = settings.filterSettings;
        m_FurRenderPass = new FurRenderPass(settings, filter);
        m_FurRenderPass.renderPassEvent = settings.PassEvent;
    }

    // "CanCopyDepth()" from "URP-Package\Runtime\UniversalRenderer.cs"
    public static bool CanCopyFurDepth(ref CameraData cameraData)
    {
        bool msaaEnabledForCamera = cameraData.cameraTargetDescriptor.msaaSamples > 1;
        bool supportsTextureCopy = SystemInfo.copyTextureSupport != CopyTextureSupport.None;
        bool supportsDepthTarget = RenderingUtils.SupportsRenderTextureFormat(RenderTextureFormat.Depth);
        bool supportsDepthCopy = !msaaEnabledForCamera && (supportsDepthTarget || supportsTextureCopy);

        bool msaaDepthResolve = msaaEnabledForCamera && SystemInfo.supportsMultisampledTextures != 0;

        // copying depth on GLES3 is giving invalid results. Needs investigation (Fogbugz issue 1339401)
        if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.OpenGLES3)
            return false;

        return supportsDepthCopy || msaaDepthResolve;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // No need to enqueue depth pass when in deferred path.
        // If GBuffer exists, URP is in deferred path.
        bool isUsingDeferred = gBufferFieldInfo.GetValue(renderer) != null;

        // From "URP-Package\Runtime\UniversalRenderer.cs", check if URP executes DepthPrepass.
        bool applyPostProcessing = renderingData.cameraData.postProcessEnabled;
        bool cameraHasPostProcessingWithDepth = applyPostProcessing && renderingData.cameraData.postProcessingRequiresDepthTexture;

        // Check if URP executes Depth Priming.
        // If Depth Priming enabled, we should enqueue DepthPrepass/DepthNormalPrepass (If require "_CameraNormalsTexture") for fur.
#if UNITY_ANDROID || UNITY_IOS || UNITY_TVOS
        bool m_DepthPrimingRecommended = false;
#else
        bool m_DepthPrimingRecommended = true;
#endif
        // On Android, iOS, and Apple TV, Unity performs depth priming only in the Force mode.
        var universalRenderer = renderingData.cameraData.renderer as UniversalRenderer;
        bool useDepthPriming = (m_DepthPrimingRecommended && universalRenderer.depthPrimingMode == DepthPrimingMode.Auto) || (universalRenderer.depthPrimingMode == DepthPrimingMode.Forced);

        // Existing Renderer Features check (If we need Depth)
        // Never enqueue fur's DepthPrepass if URP executes DepthNormalPrepass. (Instead, enqueue DepthNormalPrepass for fur.)
        RenderPassEvent beforeMainRenderingEvent = isUsingDeferred ? RenderPassEvent.BeforeRenderingGbuffer : RenderPassEvent.BeforeRenderingOpaques;
        var activeRenderPassQueue = activeRenderPassQueueFieldInfo.GetValue(renderer) as List<ScriptableRenderPass>;
        bool rendererFeatureNeedsDepth = false;
        bool rendererFeatureNeedsNormals = false;
        bool eventBeforeMainRendering = false;

        for (int i = 0; i < activeRenderPassQueue.Count; ++i)
        {
            ScriptableRenderPass pass = activeRenderPassQueue[i];
            eventBeforeMainRendering = pass.renderPassEvent <= beforeMainRenderingEvent;

            // "rendererFeatureNeedsDepth" will be true if we need "DepthTexture" before Opaque Objects rendering, 
            // which means that we cannot copy depth after rendering Opaque Objects. (such as SSAO without checking "After Opaque")
            rendererFeatureNeedsDepth |= ((pass.input & ScriptableRenderPassInput.Depth) != ScriptableRenderPassInput.None) && eventBeforeMainRendering;

            rendererFeatureNeedsNormals |= (pass.input & ScriptableRenderPassInput.Normal) != ScriptableRenderPassInput.None;
        }

        // When should we enqueue DepthPrepass pass:
        // 1. Any Renderer Feature requires depth before we can copy the depth. (such as SSAO without checking "After Opaque")
        // 2. Depth Texture checked by user/ Post-Processing requires Depth Texture,
        //    BUT the platform cannot copy depth from Lit pass (Draw Opaque Objects).
        // 3. Depth Priming enabled.
        // 
        // When shouldn't we enqueue DepthPrepass pass:
        // 1. URP executes DepthNormalPrepass, instead of DepthPrepass.
        // 2. We are in deferred path. (GBuffer pass will output depth)
        bool requiresDepthPrepass = rendererFeatureNeedsDepth || (cameraHasPostProcessingWithDepth && !CanCopyFurDepth(ref renderingData.cameraData));
        requiresDepthPrepass |= useDepthPriming && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth);

        // No need to enqueue depth pass when in deferred path.
        if (requiresDepthPrepass && !isUsingDeferred && !rendererFeatureNeedsNormals)
        {
            renderer.EnqueuePass(m_FurRenderPass);
        }
    }
}


