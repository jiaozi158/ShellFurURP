#ifndef FUR_SHELL_PARAM_HLSL
#define FUR_SHELL_PARAM_HLSL

int _ShellAmount;
float _ShellStep;
float _AlphaCutout;
float _Occlusion;
float _FurScale;
float4 _BaseMove;
float4 _WindFreq;
float4 _WindMove;
float _FaceViewProdThresh;

TEXTURE2D(_FurMap); 
SAMPLER(sampler_FurMap);
float4 _FurMap_ST;

TEXTURE2D(_NormalMap); 
SAMPLER(sampler_NormalMap);
float4 _NormalMap_ST;
float _NormalScale;

TEXTURE2D(_FurDirMap);
SAMPLER(sampler_FurDirMap);
float _GroomingIntensity;

TEXTURE2D(_FurLengthMap);
SAMPLER(sampler_FurLengthMap);
float _FurLengthIntensity;

TEXTURE2D(_AOMap);
SAMPLER(sampler_AOMap);

float _TotalShellStep;

float _FurSmoothness;
float _Backlit;
float _Area;
float _MedulaScatter;
float _MedulaAbsorb;
float _Kappa;

float _BentType;
#endif