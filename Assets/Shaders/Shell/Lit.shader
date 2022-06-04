Shader "Universal Render Pipeline/Fur/Shell/Lit"
{

Properties
{
    [Header(Basic)][Space]
    [MainColor] _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
    _BaseMap("Albedo", 2D) = "white" {}
    _Smoothness("Smoothness", Range(0.0, 0.66)) = 0.0

    [Header(Shell)][Space]
    [Space][NoScaleOffset]_FurMap("Shell Noise", 2D) = "white" {}
    _FurScale("Shell Scale", Range(0.0, 10.0)) = 1.0
    _AlphaCutout("Fur Cutout", Range(0.05, 0.5)) = 0.2
    [Space][Space][NoScaleOffset][Normal] _NormalMap("Shell Normal", 2D) = "bump" {}
    _NormalScale("Normal Scale", Range(0.0, 2.0)) = 1.0

    [Space][Space]
    [Toggle(_GEOM_INSTANCING)] _GeomInstancing("(Slow) More Shell Amount", Float) = 0
    [IntRange] _ShellAmount("Shell Amount", Range(1, 52)) = 13

    // Replaced by "Total Shell Step".
    [HideInInspector] _ShellStep("Shell Step", Range(0.0, 0.02)) = 0.001

    [Space][Space] _TotalShellStep("Total Shell Step", Range(0.0, 0.5)) = 0.026

    [Space][Header(Advanced)][Space]

    [NoScaleOffset]_AOMap("Mesh AO Map", 2D) = "white" {}
    _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.25
    [Space][Space][NoScaleOffset] _FurLengthMap("Fur Length Map", 2D) = "white" {}
    _FurLengthIntensity("Length Intensity", Range(0.01, 5.0)) = 1.0
    [Space][Space][NoScaleOffset] _FurDirMap("Fur Direction Map", 2D) = "bump" {}
    _GroomingIntensity("Direction Intensity", Range(0.0, 1.0)) = 1.0
    [Space][Enum(Linear, 0, Quadratic, 1)]_BentType("Fur Bent Type", float) = 1

    [Space][Header(Marschner Specular)][Space]
    [Toggle(_FUR_SPECULAR)] _FurSpecular("Enable", Float) = 1
    [Toggle(_FUR_SPECULAR_DEFERRED)] _FurSpecularDeferredAdditional("(Slow) Support Deferred Path", Float) = 0
    _FurSmoothness("Fur Smoothness", Range(0.0, 1.0)) = 0.45
    _Backlit("Backlit", Range(0.0, 1.0)) = 0.25
    _Area("Lit Area", Range(0.01, 1.0)) = 0.1
    _MedulaScatter("Fur Scatter", Range(0.01, 1.0)) = 0.75
    _MedulaAbsorb("Fur Absorb", Range(0.01, 0.99)) = 0.9
    _Kappa("Kappa", Range(0.01, 2.0)) = 1.0

    [Space][Header(Rim Lighting)][Space]
    _RimLightPower("Rim Light Power", Range(1.0, 20.0)) = 10.0
    _RimLightIntensity("Rim Light Intensity", Range(0.0, 1.0)) = 0.0

    [Header(Shadows)][Space]
    _ShadowExtraBias("Shadow Extra Bias", Range(-1.0, 1.0)) = 0.0
    [Toggle(_NO_FUR_SHADOW)] _NoFurShadow("(Fast) Mesh Shadow Only", Float) = 1

    [Space][Header(Others)][Space]
    [Space][Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
    [Space][ToggleOff] _SpecularHighlights("Specular Highlights On", Float) = 0.0

    [Space]
    _BaseMove("Base Move", Vector) = (0.0, 0.0, 0.0, 3.0)
    _WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
    _WindMove("Wind Move", Vector) = (0.0, 0.0, 0.0, 1.0)
    
    
}

SubShader
{
    Tags 
    { 
        "RenderType" = "Opaque" 
        "RenderPipeline" = "UniversalPipeline" 
        "UniversalMaterialType" = "Lit"
        "IgnoreProjector" = "True"
    }

    LOD 100

    ZWrite On
    ZTest LEqual
    Cull Back

    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForward" }

        ZWrite On

        HLSLPROGRAM
        // URP Keywords
#if (UNITY_VERSION >= 202111)
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _LIGHT_COOKIES
#else
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR
        #pragma multi_compile _ _GEOM_INSTANCING

        // Unity Keywords
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON
        #pragma multi_compile_fragment _ DEBUG_DISPLAY

        #pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        // if "_GEOM_INSTANCING", then Microsoft ShaderModel 4.1 (geometry shader instancing support)
        // It is "target 4.6" in Unity. (Tested on OpenGL 4.1, instancing not supported on OpenGL 4.0)
        #pragma target 4.6 _GEOM_INSTANCING
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Lit.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthOnly"
        Tags { "LightMode" = "DepthOnly" }

        ZWrite On
        ColorMask 0

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #pragma target 4.6 _GEOM_INSTANCING
        #include "./Depth.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthNormals"
        Tags { "LightMode" = "DepthNormals" }

        ZWrite On

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #pragma target 4.6 _GEOM_INSTANCING
        #include "./DepthNormals.hlsl"
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
        #pragma multi_compile _ _GEOM_INSTANCING
        #pragma multi_compile _ _NO_FUR_SHADOW

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #pragma target 4.6 _GEOM_INSTANCING
        #include "./Shadow.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "GBuffer"
        Tags { "LightMode" = "UniversalGBuffer" }

        ZWrite On

        HLSLPROGRAM
        // URP Keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR
        #pragma multi_compile_fragment _ _FUR_SPECULAR_DEFERRED
        #pragma multi_compile _ _GEOM_INSTANCING

        // Unity Keywords
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON

        //#pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        // if "_GEOM_INSTANCING", then Microsoft ShaderModel 4.1 (geometry shader instancing support)
        // It is "target 4.6" in Unity. (Tested on OpenGL 4.1, instancing not supported on OpenGL 4.0)
        #pragma target 4.6 _GEOM_INSTANCING
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./LitGBuffer.hlsl"
        ENDHLSL
    }

//---------------------------For Microsoft Shader Model < 4.1---------------------------------------------
//-----------------------Geometry Shader Instancing not supported.----------------------------------------
    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForward" }

        ZWrite On

        HLSLPROGRAM
        // URP Keywords
#if (UNITY_VERSION >= 202111)
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _LIGHT_COOKIES
#else
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR

        // Unity Keywords
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON
        #pragma multi_compile_fragment _ DEBUG_DISPLAY

        #pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Lit.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthOnly"
        Tags { "LightMode" = "DepthOnly" }

        ZWrite On
        ColorMask 0

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Depth.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthNormals"
        Tags { "LightMode" = "DepthNormals" }

        ZWrite On

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./DepthNormals.hlsl"
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
        #pragma multi_compile _ _NO_FUR_SHADOW

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Shadow.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "GBuffer"
        Tags { "LightMode" = "UniversalGBuffer" }

        ZWrite On

        HLSLPROGRAM
        // URP Keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR
        #pragma multi_compile_fragment _ _FUR_SPECULAR_DEFERRED

        // Unity Keywords
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON

        //#pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./LitGBuffer.hlsl"
        ENDHLSL
    }
}
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
