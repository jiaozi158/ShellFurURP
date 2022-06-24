#ifndef FUR_SHELL_PARAM_HLSL
#define FUR_SHELL_PARAM_HLSL

// SRP Batching.

// In this shader, position (Object Space) cannot convert to World Space on URP 13 and below. (with SRP Batching)
// See "https://forum.unity.com/threads/srp-batching-positionos-cannot-be-converted-to-positionws.1299816/".
// Please let me know if there's something I can do, thanks!
#if (UNITY_VERSION >= 202220)
CBUFFER_START(UnityPerMaterial)
#endif
float4 _BaseColor;
float _Smoothness;
float _FurScale;
float _AlphaCutout;
float _NormalScale;
int _ShellAmount;
float _TotalShellStep;

float _Occlusion;
float _FurLengthIntensity;
float _GroomingIntensity;

float _BentType;

float _FurSmoothness;
float _Backlit;
float _Area;
float _MedulaScatter;
float _MedulaAbsorb;
float _Kappa;

float _RimLightPower;
float _RimLightIntensity;

float _ShadowExtraBias;

float _Metallic;
float4 _BaseMove;
float4 _WindFreq;
float4 _WindMove;

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
#endif