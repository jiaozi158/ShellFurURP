#ifndef FUR_SHELL_LIT_HLSL
#define FUR_SHELL_LIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "./Param.hlsl"
#include "./Common.hlsl"

#if defined(_FUR_SPECULAR) && !defined(_MATERIAL_TYPE_PHYSICAL_HAIR)
#include "./FurSpecular.hlsl"
#endif

// VR single pass instance compability:
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

#if defined(_MATERIAL_TYPE_PHYSICAL_HAIR)
#include "./PhysicalHair/MarschnerHairBSDF.hlsl"
#include "./PhysicalHair/HairMultipleScattering.hlsl"
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
    half3  normalWS : NORMAL;
    half4  tangentWS : TEXCOORD0; // w is tangentOS.w
    float2 uv : TEXCOORD1;
    float2 staticLightmapUV : TEXCOORD2;
    half3  groomWS : TEXCOORD3;
    half   furLength : TEXCOORD4;
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD5;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct g2f
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    half3  normalWS : TEXCOORD1;
    half4  tangentWS : TEXCOORD2; // w is tangentOS.w
    float2 uv : TEXCOORD3;
    half   fogFactor : TEXCOORD4;
    float  layer : TEXCOORD5;
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD6;
#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

v2g vert(Attributes input)
{
    v2g output = (v2g)0;
    // setup the instanced id
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the "v2g output" to 0.0
    // This is the URP version of UNITY_INITIALIZE_OUTPUT()
    ZERO_INITIALIZE(v2g, output);
    // copy instance id in the "Attributes input" to the "v2g output"
    UNITY_TRANSFER_INSTANCE_ID(input, output);

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
    g2f output = (g2f)0;
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the g2f output to 0.0
    ZERO_INITIALIZE(g2f, output);

    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

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

    output.fogFactor = 0;
#if !defined(_FOG_FRAGMENT)
    output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
#endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    // No need to consider scale and offset here, they are calculated in vertex shader.
    output.dynamicLightmapUV = input.dynamicLightmapUV;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    stream.Append(output);
}

// For geometry shader instancing, no clamp on _ShellAmount.
void AppendShellVertexInstancing(inout TriangleStream<g2f> stream, v2g input, int index)
{
    g2f output = (g2f)0;
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the g2f output to 0.0
    ZERO_INITIALIZE(g2f, output);

    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

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

    output.fogFactor = 0;
#if !defined(_FOG_FRAGMENT)
    output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
#endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    // No need to consider scale and offset here, they are calculated in vertex shader.
    output.dynamicLightmapUV = input.dynamicLightmapUV;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);


    stream.Append(output);
}

//-----------------------------------(below) For Microsoft Shader Model > 4.1-----------------------------------
// "[instance(3)]" = 3+1 geometry shader instances, so we can have at most 13x4 = 52 shells
//
// If you need 200 shells (too much for game):
// "200 / 13 = 15, remains 5"
// 
// You will need "16" instances, "15" for 195 shells, "1" for 5 remaining shells.
// So, use [instance(15)] to execute "15+1" instances.
// 
// IMPORTANT: if you set [instance(30)] for 200 shells, you will waste performance because
//            "stream.RestartStrip()" will run on 14 istances (with empty output).
// 
//            Please keep "n" in [instance(n)] the same for all "passes.hlsl" (Lit, Depth, DepthNormals, Shadow, LitGBuffer...)
//            Or something will break! (post-processing in most cases)
// 
// LIMIT: You can only have up to 32 instances, so (32+1)x13 = 429 shells at most.
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

void frag(g2f input
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
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

    float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
    half3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, furUV),
        _NormalScale);

    half3 bitangent = SafeNormalize(input.tangentWS.w * cross(input.normalWS, input.tangentWS.xyz));
    half3 normalWS = SafeNormalize(TransformTangentToWorld(
        normalTS,
        half3x3(input.tangentWS.xyz, bitangent, input.normalWS)));

    SurfaceData surfaceData = (SurfaceData)0;

    // Avoid using it to support SRP Batching.
    //InitializeStandardLitSurfaceData(input.uv, surfaceData);

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));

#if defined (_MATERIAL_TYPE_PHYSICAL_HAIR)
    surfaceData.albedo = albedoAlpha.rgb * lerp(_RootColor.rgb, _TipColor.rgb, input.layer);
    surfaceData.metallic = 0.0;
    surfaceData.smoothness = lerp(_RootSmoothness, _TipSmoothness, input.layer);
#else
    surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    surfaceData.metallic = _Metallic;
    surfaceData.smoothness = _Smoothness;
#endif

    surfaceData.alpha = 1.0;

    half AO = (1.0 - SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, input.uv / _BaseMap_ST.xy).x) * _Occlusion;
    surfaceData.occlusion = (1.0 - AO) * lerp(1.0 - _Occlusion * _Occlusion, 1.0, input.layer);

#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewDirWS;

#if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    // Vertex Lighting will not be supported as it is not fast enough when calculating so many vertices (in geometry shader).

    inputData.vertexLighting = half3(0, 0, 0);
    //inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#endif

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif

#if !defined(_MATERIAL_TYPE_PHYSICAL_HAIR)
    outColor = UniversalFragmentPBR(inputData, surfaceData);
#endif

#if defined(_FUR_SPECULAR) && !defined(DEBUG_DISPLAY) && !defined (_MATERIAL_TYPE_PHYSICAL_HAIR)
    half3 specColor = half3(0.0, 0.0, 0.0);

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

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);

    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    _ConsiderShadow = _ConsiderShadow == 1 ? 0 : 1; // Remap from 1/0 to 0/1.

#if defined (_LIGHT_LAYERS)
#if (UNITY_VERSION >= 202220)
    uint meshRenderingLayers = GetMeshRenderingLayer();
#else
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
#endif
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        half3 mainLightColor = mainLight.color.rgb * mainLight.distanceAttenuation * saturate(mainLight.shadowAttenuation + _ConsiderShadow);
        specColor += (mainLightColor * FurBSDFYan(s, mainLight.direction, viewDirWS, normalWS, 1.0, _Backlit, _Area));

    }

    // Calculate additional lights.
#ifdef _ADDITIONAL_LIGHTS

#if USE_FORWARD_PLUS // Forward+ rendering path.
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            half3 lightColor = light.color.rgb * light.distanceAttenuation * saturate(light.shadowAttenuation + _ConsiderShadow);
            specColor += (lightColor * FurBSDFYan(s, light.direction, viewDirWS, normalWS, 1.0, _Backlit, _Area));
        }
    }

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
    {
        half3 lightColor = light.color.rgb * light.distanceAttenuation * saturate(light.shadowAttenuation + _ConsiderShadow);
        specColor += (lightColor * FurBSDFYan(s, light.direction, viewDirWS, normalWS, 1.0, _Backlit, _Area));
    }
    LIGHT_LOOP_END
#else // Forward rendering path.

    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        int index = GetPerObjectLightIndex(i);
        //Light light = GetAdditionalPerObjectLight(index, input.positionWS);
        Light light = GetAdditionalLight(index, inputData, shadowMask, aoFactor);
#if defined (_LIGHT_LAYERS)
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            half3 lightColor = light.color.rgb * light.distanceAttenuation * saturate(light.shadowAttenuation + _ConsiderShadow);
            specColor += (lightColor * FurBSDFYan(s, light.direction, viewDirWS, normalWS, 1.0, _Backlit, _Area));
        }
    }
#endif
#endif
    // Suppressing NaN values.
    outColor.rgb += max(specColor, half3(0.0, 0.0, 0.0));
#endif

#if defined (_MATERIAL_TYPE_PHYSICAL_HAIR)
    MarschnerHairSurfaceData hairSurfaceData = (MarschnerHairSurfaceData)0;

    half3 groomTS = SafeNormalize(UnpackNormal(SAMPLE_TEXTURE2D_LOD(_FurDirMap, sampler_FurDirMap, input.uv / _BaseMap_ST.xy, 0).xyzw));

    // Tangent vector (fur normal considered) for physical hair.
    half3 groomWS = SafeNormalize(TransformTangentToWorld(
        groomTS,
        half3x3(input.tangentWS.xyz, SafeNormalize(input.tangentWS.w * cross(normalWS, input.tangentWS.xyz)), normalWS)));

    // Not used by physical hair.
    //hairSurfaceData.geomNormalWS = normalWS;
    hairSurfaceData.hairStrandDirection = groomWS;// normalWS;
    hairSurfaceData.normalWS = normalWS;
    hairSurfaceData.cuticleAngle = _CuticleAngle;
    hairSurfaceData.perceptualRadialSmoothness = _RadialSmoothness;

    outColor = LightingHairFX(hairSurfaceData, surfaceData, inputData);
#endif

    // Transmission is built into the physical hair lighting model.
#if !defined(DEBUG_DISPLAY) && defined(_FUR_RIM_LIGHTING) && !defined (_MATERIAL_TYPE_PHYSICAL_HAIR)
    ApplyRimLight(outColor.rgb, input.positionWS, viewDirWS, normalWS, inputData);
#endif

    outColor.rgb = MixFog(outColor.rgb, inputData.fogCoord);

#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}

#endif
