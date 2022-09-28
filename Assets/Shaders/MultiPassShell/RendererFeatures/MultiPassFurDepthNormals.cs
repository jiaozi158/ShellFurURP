using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Reflection;

[DisallowMultipleRendererFeature("Multi-Pass Fur DepthNormals")]
[Tooltip("Add this Renderer Feature to automatically support DepthNormalPrepass for Multi-Pass Fur.")]
public class MultiPassFurDepthNormals : ScriptableRendererFeature
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
        [HideInInspector] public string passTag = "Fur DepthNormals";
        [Header("Keep It The Same For All")]
        [Tooltip("Controls the number of fur layers. Keep it the same in all Multi-Pass Fur Renderer Features.")]
        // Increase the range if you need more layers.
        [Range(1, 200)]public int ShellAmount = 13;

        // Remove the "[HideInInspector]" if you want to change the RenderPassEvent.
        [Header("Advanced")]
        [Tooltip("Controls when to enqueue the fur DepthNormalPrepass rendering. (After Rendering Pre Passes by default)")]
        [HideInInspector] public RenderPassEvent PassEvent = RenderPassEvent.AfterRenderingPrePasses;

        [HideInInspector] public FilterSettings filterSettings = new FilterSettings();
    }

    // C# Reflection
    private readonly static FieldInfo gBufferFieldInfo = typeof(UniversalRenderer).GetField("m_GBufferPass", BindingFlags.NonPublic | BindingFlags.Instance);
    private readonly static FieldInfo activeRenderPassQueueFieldInfo = typeof(ScriptableRenderer).GetField("m_ActiveRenderPassQueue", BindingFlags.NonPublic | BindingFlags.Instance);
    // For setting RenderTarget use. (unnecessary in URP 12 and below)
#if UNITY_2022_1_OR_NEWER
    private readonly static FieldInfo normalsTextureFieldInfo = typeof(UniversalRenderer).GetField("m_NormalsTexture", BindingFlags.NonPublic | BindingFlags.Instance);
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

            DrawingSettings normalDrawingSettings = CreateDrawingSettings(m_ShaderTagIdList[2], ref renderingData, sortingCriteria);

            cmd.SetGlobalFloat("_TOTAL_LAYER", settings.ShellAmount);
            for (int i = 0; i < settings.ShellAmount; i++)
            {
                cmd.SetGlobalFloat("_CURRENT_LAYER", i);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                context.DrawRenderers(renderingData.cullResults, ref normalDrawingSettings, ref filter);
            }

            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // We can set render target directly by providing name in URP 12 and below. (No need reflection)
            var renderer = renderingData.cameraData.renderer as UniversalRenderer;
#if UNITY_2022_1_OR_NEWER
            var normalsTextureHandle = normalsTextureFieldInfo.GetValue(renderer) as RTHandle;
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
            if (useDepthPriming && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth) && normalsTextureHandle != null)
                ConfigureTarget(normalsTextureHandle, renderingData.cameraData.renderer.cameraDepthTargetHandle);
            else
                ConfigureTarget(normalsTextureHandle, depthTextureHandle);
#else
            if (useDepthPriming && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth))
                ConfigureTarget("_CameraNormalsTexture", renderingData.cameraData.renderer.cameraDepthTarget);
            else
                ConfigureTarget("_CameraNormalsTexture", "_CameraDepthTexture");
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
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // No need to enqueue DepthNormals pass when in deferred path.
        // If GBuffer exists, URP is in deferred path.
        bool isUsingDeferred = gBufferFieldInfo.GetValue(renderer) != null;

        // C# Reflection
        var activeRenderPassQueue = activeRenderPassQueueFieldInfo.GetValue(renderer) as List<ScriptableRenderPass>;
        bool rendererFeatureNeedsNormals = false;
        for (int i = 0; i < activeRenderPassQueue.Count; ++i)
        {
            ScriptableRenderPass pass = activeRenderPassQueue[i];
            rendererFeatureNeedsNormals |= (pass.input & ScriptableRenderPassInput.Normal) != ScriptableRenderPassInput.None;
            // Keep this line for reference when adding fur motionVector pass.
            //rendererFeatureNeedsMotion |= (pass.input & ScriptableRenderPassInput.Motion) != ScriptableRenderPassInput.None;
        }

        // When should we enqueue DepthNormalPrepass pass:
        // 1. Any Renderer Feature requires DepthNormals. (such as SSAO using "DepthNormals" source)
        // 
        // When shouldn't we enqueue DepthNormalPrepass pass:
        // 1. We are in deferred path. (GBuffer pass will output normal)

        // Enqueue this pass if requires DepthNormals.
        if (rendererFeatureNeedsNormals && !isUsingDeferred)
        {
            renderer.EnqueuePass(m_FurRenderPass);
        }
    }
}


