using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Reflection;

[DisallowMultipleRendererFeature("Multi-Pass Fur Forward")]
[Tooltip("Add this Renderer Feature to render fur in Forward path. (currently not rendering to GBuffer in Deferred)")]
public class MultiPassFur : ScriptableRendererFeature
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
        [HideInInspector] public string passTag = "Fur ForwardLit";
        [Header("Keep It The Same For All")]
        [Tooltip("Controls the number of fur layers. Keep it the same in all Multi-Pass Fur Renderer Features.")]
        // Increase the range if you need more layers.
        [Range(1, 200)]public int ShellAmount = 13;

        // Remove the "[HideInInspector]" if you want to change the RenderPassEvent.
        [Header("Advanced")]
        [Tooltip("Controls when to enqueue the fur rendering. (Before Rendering Opaques by default)")]
        [HideInInspector] public RenderPassEvent PassEvent = RenderPassEvent.BeforeRenderingOpaques;

        [HideInInspector] public FilterSettings filterSettings = new FilterSettings();
    }

    // C# Reflection
    private readonly static FieldInfo gBufferFieldInfo = typeof(UniversalRenderer).GetField("m_GBufferPass", BindingFlags.NonPublic | BindingFlags.Instance);

    public class FurRenderPass : ScriptableRenderPass
    {
        string m_ProfilerTag;
        private PassSettings settings;
        public List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();
        private FilteringSettings filter;
        // Depth Priming needed.
        private RenderStateBlock m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);

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

            DrawingSettings drawingSetting = CreateDrawingSettings(m_ShaderTagIdList[0], ref renderingData, sortingCriteria);

            cmd.SetGlobalFloat("_TOTAL_LAYER", settings.ShellAmount);
            for (int i = 0; i < settings.ShellAmount; i++)
            {
                cmd.SetGlobalFloat("_CURRENT_LAYER", i);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                context.DrawRenderers(renderingData.cullResults, ref drawingSetting, ref filter, ref m_RenderStateBlock);
            }

            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
#if UNITY_ANDROID || UNITY_IOS || UNITY_TVOS
            bool m_DepthPrimingRecommended = false;
#else
            bool m_DepthPrimingRecommended = true;
#endif
            // Actual Depth Priming check.
            var renderer = renderingData.cameraData.renderer as UniversalRenderer;
            bool useDepthPriming = (m_DepthPrimingRecommended && renderer.depthPrimingMode == DepthPrimingMode.Auto) || (renderer.depthPrimingMode == DepthPrimingMode.Forced);

            // We need Depth Priming only in Forward path.
            // If GBuffer exists, URP is in Deferred path. (Actual rendering mode can be different from settings, such as URP forces Forward on OpenGL)
            bool isUsingDeferred = gBufferFieldInfo.GetValue(renderer) != null;

            if (useDepthPriming && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth) && !isUsingDeferred)
            {
                m_RenderStateBlock.depthState = new DepthState(false, CompareFunction.Equal);
                m_RenderStateBlock.mask |= RenderStateMask.Depth;
            }
            else if (m_RenderStateBlock.depthState.compareFunction == CompareFunction.Equal)
            {
                m_RenderStateBlock.depthState = new DepthState(true, CompareFunction.LessEqual);
                m_RenderStateBlock.mask |= RenderStateMask.Depth;
            }
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
        renderer.EnqueuePass(m_FurRenderPass);
    }
}


