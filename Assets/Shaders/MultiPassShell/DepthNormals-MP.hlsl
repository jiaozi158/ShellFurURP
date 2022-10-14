#ifndef MULTI_PASS_FUR_SHELL_DEPTH_NORMALS_HLSL
#define MULTI_PASS_FUR_SHELL_DEPTH_NORMALS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
#include "./Param-MP.hlsl"

// For VR single pass instance compability:
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// Due to unknown reasons, "DepthNormals" pass mismatch with depth in "ForwardLit" if removing Light Probes (SH) from "DepthNormals" pass. (Test Depth Priming in Unity 2022.1.2f1, URP 13.1.8)
// 
// See the 4 lines with "//...".

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1; //...
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float  layer : TEXCOORD1;
    half3  normalWS : TEXCOORD2;
    half4  tangentWS : TEXCOORD3; // w is tangentOS.w
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 4); //...
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    // setup the instanced id
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the "Varyings output" to 0.0
    // This is the URP version of UNITY_INITIALIZE_OUTPUT()
    ZERO_INITIALIZE(Varyings, output);
    // copy instance id in the "Attributes input" to the "v2g output"
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Fur Direction and Length.
    half3 groomTS = SafeNormalize(UnpackNormal(SAMPLE_TEXTURE2D_LOD(_FurDirMap, sampler_FurDirMap, input.uv / _BaseMap_ST.xy, 0).xyzw));

    half3 groomWS = SafeNormalize(TransformTangentToWorld(
        groomTS,
        half3x3(normalInput.tangentWS, normalInput.bitangentWS, normalInput.normalWS)));

    half furLength = SAMPLE_TEXTURE2D_LOD(_FurLengthMap, sampler_FurLengthMap, input.uv / _BaseMap_ST.xy, 0).x;

    float shellStep = _TotalShellStep / _TOTAL_LAYER;

    float layer = _CURRENT_LAYER / _TOTAL_LAYER;

    half moveFactor = pow(abs(layer), _BaseMove.w);
    half3 windAngle = _Time.w * _WindFreq.xyz;
    half3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + input.positionOS.xyz * _WindMove.w);
    half3 move = moveFactor * _BaseMove.xyz;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Fur Direction
    float bent = _BentType * layer + (1 - _BentType);

    groomWS = lerp(normalInput.normalWS, groomWS, _GroomingIntensity * bent);
    float3 shellDir = SafeNormalize(groomWS + move + windMove);

    float3 positionWS = vertexInput.positionWS + shellDir * (shellStep * _CURRENT_LAYER * furLength * _FurLengthIntensity);

    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.layer = layer;
    output.normalWS = normalInput.normalWS;
    output.tangentWS = half4(normalInput.tangentWS, input.tangentOS.w);

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV); //...
    OUTPUT_SH(normalInput.normalWS.xyz, output.vertexSH); //...
    return output;
}

half4 frag(Varyings input) : SV_Target
{
    float2 furUV = input.uv / _BaseMap_ST.xy * _FurScale;
    half4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, furUV);
    half alpha = furColor.r * (1.0 - input.layer);

#ifdef _ALPHATEST_ON // MSAA Alpha-To-Coverage Mask
    alpha = (alpha < _AlphaCutout) ? 0.0 : alpha;
    half alphaToCoverageAlpha = SharpenAlpha(alpha, _AlphaCutout);
    bool IsAlphaToMaskAvailable = (_AlphaToMaskAvailable != 0.0);
    alpha = IsAlphaToMaskAvailable ? alphaToCoverageAlpha : alpha;

    if (input.layer > 0.0 && alpha <= 0.0) discard;
#else
    if (input.layer > 0.0 && alpha < _AlphaCutout) discard;
#endif

#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

    half3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, furUV),
        _NormalScale);

    half3 bitangent = SafeNormalize(input.tangentWS.w * cross(input.normalWS, input.tangentWS.xyz));
    half3 normalWS = SafeNormalize(TransformTangentToWorld(
        normalTS,
        half3x3(input.tangentWS.xyz, bitangent, input.normalWS)));

    // Stores World Space Normal to "_CameraNormalsTexture".
    return half4(NormalizeNormalPerPixel(normalWS), 0.0);
}

#endif