#ifndef FUR_SHELL_LIT_META_PASS_INCLUDED
#define FUR_SHELL_LIT_META_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UniversalMetaPass.hlsl"

half4 UniversalFragmentMetaLit(Varyings input) : SV_Target
{
    SurfaceData surfaceData = (SurfaceData)0;

    // Avoid using it to support SRP Batching.
    //InitializeStandardLitSurfaceData(input.uv, surfaceData);

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
#if defined (_MATERIAL_TYPE_PHYSICAL_HAIR)
    // Lacking layer information, use average value instead.
    surfaceData.albedo = albedoAlpha.rgb * (_RootColor.rgb + _TipColor.rgb) / 2.0;
    surfaceData.metallic = 0.0;
    surfaceData.smoothness = (_RootSmoothness + _TipSmoothness) / 2.0;
#else
    surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    surfaceData.metallic = _Metallic;
    surfaceData.smoothness = _Smoothness;
#endif
    surfaceData.alpha = 1.0;

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
    metaInput.Emission = surfaceData.emission;
    return UniversalFragmentMeta(input, metaInput);
}
#endif