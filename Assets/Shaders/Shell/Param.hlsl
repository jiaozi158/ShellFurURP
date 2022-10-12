#ifndef FUR_SHELL_PARAM_HLSL
#define FUR_SHELL_PARAM_HLSL

// SRP Batching.

// In this shader, position (Object Space) cannot convert to World Space on URP 13 and below. (with SRP Batching)
// See "https://forum.unity.com/threads/srp-batching-positionos-cannot-be-converted-to-positionws.1299816/".
// Please let me know if there's something I can do, thanks!
#if (UNITY_VERSION >= 202220)
CBUFFER_START(UnityPerMaterial)
#endif
half4 _BaseColor;
half _Smoothness;
half _FurScale;
half _AlphaCutout;
half _NormalScale;
half _ShellAmount;
half _TotalShellStep;

half _Occlusion;
half _FurLengthIntensity;
half _GroomingIntensity;

half _BentType;

half _ConsiderShadow;
half _FurSmoothness;
half _Backlit;
half _Area;
half _MedulaScatter;
half _MedulaAbsorb;
half _Kappa;

half4 _RootColor;
half4 _TipColor;
half _RootSmoothness;
half _TipSmoothness;
half _CuticleAngle;
half _RadialSmoothness;

half _RimLightPower;
half _RimLightIntensity;

half _ShadowExtraBias;

half _Metallic;
half4 _BaseMove;
half4 _WindFreq;
half4 _WindMove;

float4 _BaseMap_ST;
float4 _FurMap_ST;
#if (UNITY_VERSION >= 202220)
CBUFFER_END
#endif

//Textures and Samplers should not be stored in cbuffer.
TEXTURE2D(_FurMap);
SAMPLER(sampler_FurMap);

TEXTURE2D(_NormalMap); 
SAMPLER(sampler_NormalMap);

TEXTURE2D(_FurDirMap);
SAMPLER(sampler_FurDirMap);

TEXTURE2D(_FurLengthMap);
SAMPLER(sampler_FurLengthMap);

TEXTURE2D(_AOMap);
SAMPLER(sampler_AOMap);

TEXTURE3D(_PreIntegratedAverageHairFiberScattering);
SAMPLER(s_point_clamp_sampler);
#endif