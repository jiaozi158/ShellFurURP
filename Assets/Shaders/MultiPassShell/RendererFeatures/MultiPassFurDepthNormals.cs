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

    public enum DecalMode
    {
        [InspectorName("None")]
        Invalid,
        Automatic,
        [InspectorName("DBuffer")]
        DBuffer,
        ScreenSpace,
        //GBuffer, // Multi-Pass Fur does not render to GBuffer by now.
    };

    [System.Serializable]
    public class PassSettings
    {
        [HideInInspector] public string passTag = "Fur DepthNormals";
        [Header("Keep It The Same For All")]
        [Tooltip("Controls the number of fur layers. Keep it the same in all Multi-Pass Fur Renderer Features.")]
        // Increase the range if you need more layers.
        [Range(1, 200)]public int ShellAmount = 13;

        [Header("Advanced")]
        [Tooltip("Please specify the current Decal Technique if enabling Decal Renderer Feature. Has no effect when Decal is disabled.")]
        public DecalMode decalMode = DecalMode.Invalid;

        // Remove the "[HideInInspector]" if you want to change the RenderPassEvent.
        [Tooltip("Controls when to enqueue the fur DepthNormalPrepass rendering. (After Rendering Pre Passes by default)")]
        [HideInInspector] public RenderPassEvent PassEvent = RenderPassEvent.AfterRenderingPrePasses;

        [HideInInspector] public FilterSettings filterSettings = new FilterSettings();
    }

    // C# Reflection
    private readonly static FieldInfo gBufferFieldInfo = typeof(UniversalRenderer).GetField("m_GBufferPass", BindingFlags.NonPublic | BindingFlags.Instance);
    private readonly static FieldInfo activeRenderPassQueueFieldInfo = typeof(ScriptableRenderer).GetField("m_ActiveRenderPassQueue", BindingFlags.NonPublic | BindingFlags.Instance);
    private readonly static FieldInfo activeRendererFeatureFieldInfo = typeof(ScriptableRenderer).GetField("m_RendererFeatures", BindingFlags.NonPublic | BindingFlags.Instance);
    // For setting RenderTarget use. (unnecessary in URP 12 and below)
#if UNITY_2022_1_OR_NEWER
    private readonly static FieldInfo normalsTextureFieldInfo = typeof(UniversalRenderer).GetField("m_NormalsTexture", BindingFlags.NonPublic | BindingFlags.Instance);
    private readonly static FieldInfo depthTextureFieldInfo = typeof(UniversalRenderer).GetField("m_DepthTexture", BindingFlags.NonPublic | BindingFlags.Instance);
#endif

    // From "DecalRendererFeature.cs".
    public bool IsAutomaticDBuffer()
    {
        // As WebGL uses gles here we should not use DBuffer
#if UNITY_EDITOR
        if (UnityEditor.EditorUserBuildSettings.selectedBuildTargetGroup == UnityEditor.BuildTargetGroup.WebGL)
            return false;
#else
        if (Application.platform == RuntimePlatform.WebGLPlayer)
            return false;
#endif
        return !GraphicsSettings.HasShaderDefine(BuiltinShaderDefine.SHADER_API_MOBILE);
    }

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
            // Avoid null reference exception when Decal Mode (user provide) does not match the actual Decal Mode.
            else if (normalsTextureHandle != null)
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

        // Decal Renderer Feature is not a Render Pass, and it does not have a public method to return what it needs for rendering. (e.g. DepthNormal required?)
        // 
        // If Decal Renderer Feature (DBuffer mode) enabled, enqueue the Fur DepthNormalPrepass.
        // C# Reflection
        var activeRendererFeatures = activeRendererFeatureFieldInfo.GetValue(renderer) as List<ScriptableRendererFeature>;
        for (int i = 0; i < activeRendererFeatures.Count; ++i)
        {
            ScriptableRendererFeature feature = activeRendererFeatures[i];
            // Get the Decal Renderer Feature mode, if it exists.
            if (feature.isActive && feature.name == "DecalRendererFeature")
            {
                // How can we automatically get the current Decal Renderer Feature mode?

                //bool decalNeedsNormals = DBuffer : ScreenSpace?;
                //rendererFeatureNeedsNormals |= decalNeedsNormals;

                // Need to enqueue a DepthNormalPrepass for fur when using DBuffer Decal.
                if (settings.decalMode == DecalMode.DBuffer || (settings.decalMode == DecalMode.Automatic) && IsAutomaticDBuffer())
                {
                    rendererFeatureNeedsNormals |= true;
                }

            }
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


