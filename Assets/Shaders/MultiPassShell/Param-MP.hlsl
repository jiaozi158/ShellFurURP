#ifndef MULTI_PASS_FUR_SHELL_PARAM_HLSL
#define MULTI_PASS_FUR_SHELL_PARAM_HLSL

// Shader's global variable.
half _CURRENT_LAYER;
half _TOTAL_LAYER;

// SRP Batching.

CBUFFER_START(UnityPerMaterial)

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

half _FurSmoothness;
half _Backlit;
half _Area;
half _MedulaScatter;
half _MedulaAbsorb;
half _Kappa;

half _RimLightPower;
half _RimLightIntensity;

half _ShadowExtraBias;

half _Metallic;
half4 _BaseMove;
half4 _WindFreq;
half4 _WindMove;

float4 _BaseMap_ST;
float4 _FurMap_ST;

CBUFFER_END


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