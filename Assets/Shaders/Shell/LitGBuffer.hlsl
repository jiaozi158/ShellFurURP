#ifndef FUR_SHELL_LIT_DEFERRED_HLSL
#define FUR_SHELL_LIT_DEFERRED_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "./Param.hlsl"
#include "./Common.hlsl"
#if defined(_FUR_SPECULAR) && defined(_FUR_SPECULAR_DEFERRED)
#include "./FurSpecular.hlsl"
#endif
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

// VR single pass instance compability:
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    float2 dynamicLightmapUV : TEXCOORD2; // Dynamic lightmap UVs
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2g
{
    float4 positionOS : POSITION;
    half3 normalWS : NORMAL;
    half4 tangentWS : TANGENT; // w is tangentOS.w
    float2 uv : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    half3  groomWS : TEXCOORD2;
    half   furLength : TEXCOORD3;
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD4;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct g2f
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    half3  normalWS : TEXCOORD1;
    half4  tangentWS : TEXCOORD2; // w is tangentOS.w
    float2 uv : TEXCOORD3;
    float  layer : TEXCOORD4;
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD5;
#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 6);
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

v2g vert(Attributes input)
{
    v2g output = (v2g)0; // or use "v2g output" and "ZERO_INITIALIZE(v2g, output)"

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Fur Direction and Length (reusable data for geometry shader)
    half3 groomTS = SafeNormalize(UnpackNormal(SAMPLE_TEXTURE2D_LOD(_FurDirMap, sampler_FurDirMap, input.uv / _BaseMap_ST.xy, 0).xyzw));

    output.groomWS = SafeNormalize(TransformTangentToWorld(
        groomTS,
        half3x3(normalInput.tangentWS, normalInput.bitangentWS, normalInput.normalWS)));

    output.furLength = SAMPLE_TEXTURE2D_LOD(_FurLengthMap, sampler_FurLengthMap, input.uv / _BaseMap_ST.xy, 0).x;

    output.positionOS = input.positionOS;
    output.normalWS = normalInput.normalWS;
    output.tangentWS = half4(normalInput.tangentWS, input.tangentOS.w);
    output.uv = input.uv;
    output.staticLightmapUV = input.staticLightmapUV;
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    return output;
}

void AppendShellVertex(inout TriangleStream<g2f> stream, v2g input, int index)
{
    // set all values in the g2f output to 0.0
    g2f output = (g2f)0; // or use "g2f output" and "ZERO_INITIALIZE(g2f, output)"

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // Low precision should be enough here as we have at most 13 shells.
    half clampedShellAmount = clamp(_ShellAmount, 1, 13);
    half shellStep = _TotalShellStep / clampedShellAmount;

    half layer = (half)index / clampedShellAmount;

    half moveFactor = pow(abs(layer), _BaseMove.w);
    half3 windAngle = _Time.w * _WindFreq.xyz;
    half3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + input.positionOS.xyz * _WindMove.w);
    half3 move = moveFactor * _BaseMove.xyz;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Fur Direction
    half bent = _BentType * layer + (1 - _BentType);

    half3 groomWS = lerp(input.normalWS, input.groomWS, _GroomingIntensity * bent);
    half3 shellDir = SafeNormalize(groomWS + move + windMove);
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    output.positionWS = vertexInput.positionWS + shellDir * (shellStep * index * input.furLength * _FurLengthIntensity);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = input.normalWS;
    output.tangentWS = input.tangentWS;
    output.layer = layer;

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);


    stream.Append(output);
}

// For geometry shader instancing, no clamp on _ShellAmount.
void AppendShellVertexInstancing(inout TriangleStream<g2f> stream, v2g input, int index)
{
    // set all values in the g2f output to 0.0
    g2f output = (g2f)0; // or use "g2f output" and "ZERO_INITIALIZE(g2f, output)"

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    float shellStep = _TotalShellStep / _ShellAmount;

    float layer = (float)index / _ShellAmount;

    float moveFactor = pow(abs(layer), _BaseMove.w);
    half3 windAngle = _Time.w * _WindFreq.xyz;
    half3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + input.positionOS.xyz * _WindMove.w);
    float3 move = moveFactor * _BaseMove.xyz;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Fur Direction
    float bent = _BentType * layer + (1 - _BentType);

    float3 groomWS = lerp(input.normalWS, input.groomWS, _GroomingIntensity * bent);
    float3 shellDir = SafeNormalize(groomWS + move + windMove);
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    output.positionWS = vertexInput.positionWS + shellDir * (shellStep * index * input.furLength * _FurLengthIntensity);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = input.normalWS;
    output.tangentWS = input.tangentWS;
    output.layer = layer;

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);


    stream.Append(output);
}

//-----------------------------------(below) For Microsoft Shader Model > 4.1-----------------------------------
// See "Lit.hlsl" for more information.
#if defined(_GEOM_INSTANCING)
[instance(3)]
[maxvertexcount(39)]
void geom(triangle v2g input[3], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID)
{
    // 13 is calculated manually, because "maxvertexcount" is 39 in "Lit.hlsl", keep all passes to have the smallest (39 now).
    // If not, DepthNormals will be incorrect and Depth Priming (DepthNormal Mode) won't work.
    // "39 / 3 = 13", 3 means 3 vertices of a tirangle.
    [loop] for (float i = 0 + (instanceID * 13); i < _ShellAmount; ++i)
    {
        [unroll] for (float j = 0; j < 3; ++j)
        {
            AppendShellVertexInstancing(stream, input[j], i);
        }
        stream.RestartStrip();
    }
}
//-----------------------------------(above) For Microsoft Shader Model > 4.1-----------------------------------

//-----------------------------------(below) For Microsoft Shader Model < 4.1-----------------------------------
// For device that does not support geometry shader instancing.
// Available since Microsoft Shader Model 4.1, it is "target 4.6" in Unity.
#else
[maxvertexcount(39)]
void geom(triangle v2g input[3], inout TriangleStream<g2f> stream)
{
    [loop] for (float i = 0; i < clamp(_ShellAmount, 1, 13); ++i)
    {
        [unroll] for (float j = 0; j < 3; ++j)
        {
            AppendShellVertex(stream, input[j], i);
        }
        stream.RestartStrip();
    }
}
#endif
//-----------------------------------(above) For Microsoft Shader Model < 4.1-----------------------------------

FragmentOutput frag(g2f input)
{
    UNITY_SETUP_INSTANCE_ID(input);
#if UNITY_ANY_INSTANCING_ENABLED
    // As we use geometry shaders, we manually set the StereoEyeIndex based on current instanceID.
    unity_StereoEyeIndex = UNITY_GET_INSTANCE_ID(input);
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
#endif

    float2 furUV = input.uv / _BaseMap_ST.xy * _FurScale;
    half4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, furUV);
    half alpha = furColor.r * (1.0 - input.layer);
    if (input.layer > 0.0 && alpha < _AlphaCutout) discard;

    float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
    half3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, furUV),
        _NormalScale);
    // 1.0 should be tangentOS.w, not passing it to fragment shader to keep 39 max vertex counts.
    half3 bitangent = SafeNormalize(input.tangentWS.w * cross(input.normalWS, input.tangentWS.xyz));
    half3 normalWS = SafeNormalize(TransformTangentToWorld(
        normalTS,
        half3x3(input.tangentWS.xyz, bitangent, input.normalWS)));

    SurfaceData surfaceData = (SurfaceData)0;

    // Avoid using it to support SRP Batching.
    //InitializeStandardLitSurfaceData(input.uv, surfaceData);

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    surfaceData.alpha = 1.0;
    surfaceData.metallic = _Metallic;
    surfaceData.smoothness = _Smoothness;

    half AO = (1.0 - SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, input.uv / _BaseMap_ST.xy).x) * _Occlusion;
    surfaceData.occlusion = (1.0 - AO) * lerp(1.0 - _Occlusion * _Occlusion, 1.0, input.layer);

#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewDirWS;
//#if defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_RECEIVE_SHADOWS_OFF)
#if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = 0.0; // URP doesn't apply fog in gbuffer pass.

    // Vertex Lighting will not be supported as it is not fast enough when calculating so many vertices (in geometry shader).
    inputData.vertexLighting = half3(0, 0, 0);
    //inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

#if UNITY_VERSION >= 600000
    SETUP_DEBUG_TEXTURE_DATA(inputData, UNDO_TRANSFORM_TEX(input.uv, _BaseMap));
#else
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
#endif

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif

    // Get the main light.
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    _ConsiderShadow = _ConsiderShadow == 1 ? 0 : 1; // Remap from 1/0 to 0/1.

    half3 color = half3(0.0, 0.0, 0.0);

#if defined(_FUR_RIM_LIGHTING) && defined (_FUR_RIM_LIGHTING_DEFERRED)
    // Calculate Rim Light
    ApplyRimLightDeferred(color, input.positionWS, viewDirWS, normalWS, inputData);
#endif
    
#if defined(_FUR_SPECULAR) && defined(_FUR_SPECULAR_DEFERRED)
    // Use abs(f) to avoid warning messages that f should not be negative in pow(f, e).
    SurfaceOutputFur s = (SurfaceOutputFur)0;
    s.Albedo = abs(surfaceData.albedo);
    s.MedulaScatter = abs(_MedulaScatter);
    s.MedulaAbsorb = abs(1.0 - _MedulaAbsorb);
    // Convert smoothness to roughness, (1 - smoothness) is perceptual roughness.
    s.Roughness = (1.0 - _FurSmoothness) * (1.0 - _FurSmoothness);
    // Avoid 0 layer.
    s.Layer = input.layer + 0.001;
    s.Kappa = (1.0 - _Kappa / 2.0);

#ifdef _LIGHT_LAYERS
    #if (UNITY_VERSION >= 202220)
    uint meshRenderingLayers = GetMeshRenderingLayer();
    #else
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    #endif
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        half3 mainLightColor = mainLight.color.rgb * mainLight.distanceAttenuation * saturate(mainLight.shadowAttenuation + _ConsiderShadow);
        color += (mainLightColor * FurBSDFYan(s, mainLight.direction, viewDirWS, normalWS, 1.0, _Backlit, _Area));
    }

    // Additional Lights in deferred can be very slow. (not suggested)
    // Max Light count is still 8 per object.
    // A better solution is to customize URP's deferred rendering.
#ifdef _ADDITIONAL_LIGHTS
    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        int index = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(index, input.positionWS);
#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            half3 lightColor = light.color.rgb * light.distanceAttenuation * saturate(light.shadowAttenuation + _ConsiderShadow);
            color += (lightColor * FurBSDFYan(s, light.direction, viewDirWS, normalWS, 1.0, _Backlit, _Area));
        }
    }
#endif
    // [important] Use saturate to avoid NaN, Inf or Negative values.
    color = saturate(color);
#endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);

    // Store GI, Emission, Rim Light, and Fur Specular in the GBuffer3.

    color += GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    FragmentOutput output = BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);

    return output;
}
#endif
