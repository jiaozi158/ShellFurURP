Shader "Universal Render Pipeline/Fur/Multi-Pass Shell/Lit"
{

Properties
{
    [Header(Rendering)] [Space]
    [Space(10)] [KeywordEnum(Lit, Physical Hair)] _Material_Type("Material Type", Float) = 0

    [Header(Basic)][Space]
    [MainTexture] _BaseMap("Mesh Albedo", 2D) = "white" {}

    [Space][NoScaleOffset]_FurMap("Fur Noise", 2D) = "white" {}
    _FurScale("Noise Scale", Range(0.0, 10.0)) = 1.0
    _AlphaCutout("Fur Cutout", Range(0.05, 0.5)) = 0.2
    [Space(10)][NoScaleOffset][Normal] _NormalMap("Fur Normal", 2D) = "bump" {}
    _NormalScale("Normal Scale", Range(0.0, 2.0)) = 1.0

    [Space(10)]
    // Not used in Multi-Pass Fur.
    [HideInInspector][Toggle(_GEOM_INSTANCING)] _GeomInstancing("(Slow) More Shell Amount", Float) = 0.0
    [HideInInspector][Space(10)][IntRange] _ShellAmount("Shell Amount", Range(1, 52)) = 13
    [Header(Shell Amount In Renderer Feature)][Space(10)]
    _TotalShellStep("Total Shell Step", Range(0.0, 0.5)) = 0.026

    [Space][Header(Advanced)][Space]
    [NoScaleOffset]_AOMap("Mesh AO Map", 2D) = "white" {}
    _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.25
    [Space(10)][NoScaleOffset] _FurLengthMap("Fur Length Map", 2D) = "white" {}
    _FurLengthIntensity("Length Intensity", Range(0.01, 5.0)) = 1.0
    [Space(10)][NoScaleOffset] _FurDirMap("Fur Direction Map", 2D) = "bump" {}
    _GroomingIntensity("Direction Intensity", Range(0.0, 1.0)) = 1.0
    [Space(10)][Enum(Linear, 0, Quadratic, 1)]_BentType("Fur Bent Type", Float) = 1
    [Toggle(_ALPHATEST_ON)] _AlphaToCoverageOn("MSAA Alpha-To-Coverage", Float) = 1

    [Space][Header(Lit Material Settings)][Space]
    [MainColor] _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
    [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
    _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.0
    [ToggleOff] _SpecularHighlights("Specular Highlights On", Float) = 0.0

    [Space(10)][Toggle(_FUR_SPECULAR)] _FurSpecular("Marschner Specular", Float) = 1
    // Not used in Multi-Pass Fur.
    [HideInInspector][Toggle(_FUR_SPECULAR_DEFERRED)] _FurSpecularDeferred("(Slow) Support Deferred Path", Float) = 0.0
    [Toggle] _ConsiderShadow("Consider Shadow", Float) = 0.0
    _FurSmoothness("Fur Smoothness", Range(0.0, 1.0)) = 0.45
    _Backlit("Backlit", Range(0.0, 1.0)) = 0.25
    _Area("Lit Area", Range(0.01, 1.0)) = 0.1
    _MedulaScatter("Fur Scatter", Range(0.01, 1.0)) = 0.75
    _MedulaAbsorb("Fur Absorb", Range(0.01, 0.99)) = 0.9
    _Kappa("Kappa", Range(0.01, 2.0)) = 1.0

    [Space(10)][Toggle(_FUR_RIM_LIGHTING)] _FurRimLighting("Rim Lighting", Float) = 0.0
    // Not used in Multi-Pass Fur.
    [HideInInspector][Toggle(_FUR_RIM_LIGHTING_DEFERRED)] _FurRimLightingDeferred("(Slow) Support Deferred Path", Float) = 0
    _RimLightPower("Rim Light Power", Range(1.0, 20.0)) = 10.0
    _RimLightIntensity("Rim Light Intensity", Range(0.0, 1.0)) = 0.0

    [Space][Header(Physical Hair Material Settings)][Space]
    // Preintegrated hair scattering.
    [NoScaleOffset]_PreIntegratedAverageHairFiberScattering("PreIntegrated Average Scattering", 3D) = "white" {}
    _RootColor("Root Color", Color) = (1.0, 1.0, 1.0, 1.0)
    _TipColor("Tip Color", Color) = (1.0, 1.0, 1.0, 1.0)
    _RootSmoothness("Root Smoothness", Range(0.0, 1.0)) = 0.6
    _TipSmoothness("Tip Smoothness", Range(0.0, 1.0)) = 0.8
    // The angle (in degrees) that the scales on a hair fiber tilt from the strand direction.
    // For human hair, this value is usually between 2 to 3 degrees. Use this property to "shift" the highlight.
    _CuticleAngle("Cuticle Angle", Float) = 3.0
    // Controls the internal scattering of light paths and the amount of light the hair fiber absorbs.
    // 0.7 is good for human hair, animal fur would be lower.
    _RadialSmoothness("Radial Smoothness", Range(0.0, 1.0)) = 0.7

    [Space][Header(Shadows)][Space]
    _ShadowExtraBias("Shadow Extra Bias", Range(-1.0, 1.0)) = 0.0
    // Not used in Multi-Pass Fur.
    [HideInInspector][Toggle(_NO_FUR_SHADOW)] _NoFurShadow("(Fast) Mesh Shadow Only", Float) = 1.0

    [Space][Header(Others)][Space]
    _BaseMove("Base Move", Vector) = (0.0, 0.0, 0.0, 3.0)
    _WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
    _WindMove("Wind Move", Vector) = (0.0, 0.0, 0.0, 1.0)
}

SubShader
{
    Tags 
    {
        "RenderPipeline" = "UniversalPipeline"
        "RenderType" = "Opaque"
        "IgnoreProjector" = "True"
        "Queue" = "AlphaTest"
        "UniversalMaterialType" = "Lit"
    }

    LOD 100

    ZWrite On
    ZTest LEqual
    Cull Back

    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForwardFur" }

        ZWrite On
        AlphaToMask [_AlphaToCoverageOn]

        HLSLPROGRAM
        // URP Keywords
#if (UNITY_VERSION >= 202111)
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _LIGHT_COOKIES
#else
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif

#if (UNITY_VERSION >= 202220)
        #pragma shader_feature_local_fragment _ _ALPHATEST_ON
        #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
        #pragma multi_compile _ _FORWARD_PLUS
        #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
#endif

        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF

        #pragma shader_feature_fragment _ _FUR_SPECULAR
        #pragma shader_feature_fragment _ _FUR_RIM_LIGHTING
        #pragma shader_feature_fragment _ _MATERIAL_TYPE_PHYSICAL_HAIR

        // Unity Keywords
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile _ DYNAMICLIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON
        #pragma multi_compile_fragment _ DEBUG_DISPLAY

        #pragma exclude_renderers gles

        #pragma vertex vert
        #pragma fragment frag
        #include "./Lit-MP.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthOnly"
        Tags { "LightMode" = "DepthOnlyFur" }

        ZWrite On
        ColorMask R

        HLSLPROGRAM
#if (UNITY_VERSION >= 202220)
        #pragma shader_feature_local_fragment _ _ALPHATEST_ON
        #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
#endif

        #pragma exclude_renderers gles

        #pragma vertex vert
        #pragma fragment frag
        #include "./Depth-MP.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthNormals"
        Tags { "LightMode" = "DepthNormalsFur" }

        ZWrite On

        HLSLPROGRAM
#if (UNITY_VERSION >= 202220)
        #pragma shader_feature_local_fragment _ _ALPHATEST_ON
        #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
#endif

        #pragma exclude_renderers gles

        #pragma vertex vert
        #pragma fragment frag
        #include "./DepthNormals-MP.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "ShadowCaster"
        Tags { "LightMode" = "ShadowCaster" }

        ZWrite On
        ZTest LEqual
        ColorMask 0

        HLSLPROGRAM
        //#pragma multi_compile _ _NO_FUR_SHADOW
#if (UNITY_VERSION >= 202220)
        #pragma shader_feature_local_fragment _ _ALPHATEST_ON
        #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
#endif

        #pragma exclude_renderers gles

        #pragma vertex vert
        #pragma fragment frag
        #include "./Shadow-MP.hlsl"
        ENDHLSL
    }

    // Does not support GBuffer by now.
    Pass
    {
        Name "GBuffer"
        Tags { "LightMode" = "UniversalGBufferFur" }

        ZWrite On

        HLSLPROGRAM
        // URP Keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
#if (UNITY_VERSION >= 202220)
        #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
        #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
#endif

        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR
        #pragma multi_compile_fragment _ _FUR_SPECULAR_DEFERRED
        #pragma shader_feature_fragment _ _FUR_RIM_LIGHTING
        #pragma shader_feature_fragment _ _FUR_RIM_LIGHTING_DEFERRED

        // Unity Keywords
        #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile _ DYNAMICLIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON

        #pragma exclude_renderers gles

        #pragma target 3.5
        #pragma vertex vert
        #pragma fragment frag
        #include "./LitGBuffer-MP.hlsl"
        ENDHLSL
    }

    // Meta pass is used for (static/dynamic) lightmap baking only.
    Pass
    {
        Name "Meta"
        Tags { "LightMode" = "Meta" }

        Cull Off

        HLSLPROGRAM
        #pragma shader_feature EDITOR_VISUALIZATION
        #pragma shader_feature _ _MATERIAL_TYPE_PHYSICAL_HAIR

        #pragma exclude_renderers gles

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
        #include "./Param-MP.hlsl"
        #include "./LitMetaPass-MP.hlsl"
        
        #pragma vertex UniversalVertexMeta
        #pragma fragment UniversalFragmentMetaLit
        ENDHLSL
    }
}
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
