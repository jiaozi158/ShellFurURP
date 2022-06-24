#ifndef FUR_COMMON_HLSL
#define FUR_COMMON_HLSL

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Main Light Direction.
float3 _LightDirection;

inline float3 GetViewDirectionOS(float3 posOS)
{
    float3 cameraOS = TransformWorldToObject(GetCameraPositionWS());
    return normalize(posOS - cameraOS);
}

inline float3 CustomApplyShadowBias(float3 positionWS, float3 normalWS)
{
    positionWS += _LightDirection * (_ShadowBias.x + _ShadowExtraBias);
    float invNdotL = 1.0 - saturate(dot(_LightDirection, normalWS));
    float scale = invNdotL * _ShadowBias.y;
    positionWS += normalWS * scale.xxx;

    return positionWS;
}

inline float4 GetShadowPositionHClip(float3 positionWS, float3 normalWS)
{
    positionWS = CustomApplyShadowBias(positionWS, normalWS);
    float4 positionCS = TransformWorldToHClip(positionWS);
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif
    return positionCS;
}

void ApplyRimLight(inout float3 color, float3 posWS, float3 viewDirWS, float3 normalWS, InputData inputData = (InputData)0)
{
    float viewDotNormal = abs(dot(viewDirWS, normalWS));
    float normalFactor = pow(abs(1.0 - viewDotNormal), _RimLightPower);

    Light light = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
#if defined (_LIGHT_LAYERS)
    #if (UNITY_VERSION >= 202220)
    uint meshRenderingLayers = GetMeshRenderingLayer();
    #else
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    #endif
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
    {
        float lightDirDotView = dot(light.direction, viewDirWS);
        float intensity = pow(max(-lightDirDotView, 0.0), _RimLightPower);
        intensity *= _RimLightIntensity * normalFactor;
#ifdef _MAIN_LIGHT_SHADOWS
        float4 shadowCoord = TransformWorldToShadowCoord(posWS);
        intensity *= MainLightRealtimeShadow(shadowCoord);
#endif 
        color += intensity * light.color;
    }

#ifdef _ADDITIONAL_LIGHTS
    int additionalLightsCount = GetAdditionalLightsCount();

#if USE_FORWARD_PLUS // Forward+ rendering path.
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, posWS);
#if defined (_LIGHT_LAYERS)
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            float lightDirDotView = dot(light.direction, viewDirWS);
            float intensity = max(-lightDirDotView, 0.0);
            intensity *= _RimLightIntensity * normalFactor;
            intensity *= light.distanceAttenuation;
#ifdef _ADDITIONAL_LIGHT_SHADOWS
            intensity *= AdditionalLightRealtimeShadow(lightIndex, posWS);
#endif
            color += intensity * light.color;
        }
    }

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, posWS);

#if defined (_LIGHT_LAYERS)
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
    {
        float lightDirDotView = dot(light.direction, viewDirWS);
        float intensity = max(-lightDirDotView, 0.0);
        intensity *= _RimLightIntensity * normalFactor;
        intensity *= light.distanceAttenuation;
#ifdef _ADDITIONAL_LIGHT_SHADOWS
        intensity *= AdditionalLightRealtimeShadow(lightIndex, posWS);
#endif
        color += intensity * light.color;
    }
    LIGHT_LOOP_END

#else // Forward rendering path.

    for (int i = 0; i < additionalLightsCount; ++i)
    {
        int index = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(index, posWS);
#if defined (_LIGHT_LAYERS)
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            float lightDirDotView = dot(light.direction, viewDirWS);
            float intensity = max(-lightDirDotView, 0.0);
            intensity *= _RimLightIntensity * normalFactor;
            intensity *= light.distanceAttenuation;
#ifdef _ADDITIONAL_LIGHT_SHADOWS
            intensity *= AdditionalLightRealtimeShadow(index, posWS);
#endif
            color += intensity * light.color;
        }
    }
#endif
#endif
}

void ApplyRimLightDeferred(inout float3 color, float3 posWS, float3 viewDirWS, float3 normalWS, InputData inputData = (InputData)0)
{
    float viewDotNormal = abs(dot(viewDirWS, normalWS));
    float normalFactor = pow(abs(1.0 - viewDotNormal), _RimLightPower);

    Light light = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
#if defined (_LIGHT_LAYERS)
    #if (UNITY_VERSION >= 202220)
    uint meshRenderingLayers = GetMeshRenderingLayer();
    #else
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    #endif
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
    {
        float lightDirDotView = dot(light.direction, viewDirWS);
        float intensity = pow(max(-lightDirDotView, 0.0), _RimLightPower);
        intensity *= _RimLightIntensity * normalFactor;
#ifdef _MAIN_LIGHT_SHADOWS
        float4 shadowCoord = TransformWorldToShadowCoord(posWS);
        intensity *= MainLightRealtimeShadow(shadowCoord);
#endif 
        color += intensity * light.color;
    }

#if defined (_ADDITIONAL_LIGHTS)
    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        int index = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(index, posWS);
#if defined (_LIGHT_LAYERS)
        
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            float lightDirDotView = dot(light.direction, viewDirWS);
            float intensity = max(-lightDirDotView, 0.0);
            intensity *= _RimLightIntensity * normalFactor;
            intensity *= light.distanceAttenuation;
#ifdef _ADDITIONAL_LIGHT_SHADOWS
            intensity *= AdditionalLightRealtimeShadow(index, posWS);
#endif 
            color += intensity * light.color;
        }
    }
#endif
}

inline float rand(float2 seed)
{
    return frac(sin(dot(seed.xy, float2(12.9898, 78.233))) * 43758.5453);
}

inline float3 rand3(float2 seed)
{
    return 2.0 * (float3(rand(seed * 1), rand(seed * 2), rand(seed * 3)) - 0.5);
}

#endif
