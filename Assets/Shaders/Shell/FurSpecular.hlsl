#ifndef FUR_SPECULAR_HLSL
#define FUR_SPECULAR_HLSL

//-------------------------------------------------------------------------------------------------
// Fur shading from "maajor"'s https://github.com/maajor/Marschner-Hair-Unity, licensed under MIT.
//-------------------------------------------------------------------------------------------------

struct SurfaceOutputFur
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
//#pragma exclude_renderers d3d11 gles
{
	half3 Albedo;
	half MedulaScatter;
	half MedulaAbsorb;
	//half3 Normal; //Tangent actually
	//half3 VNormal; //vertext normal
	//half3 Emission;
	//half Alpha;
	half Roughness;
	//half Specular;
	half Layer;
	half Kappa;
};

inline half square(half x)
{
	return x * x;
}

half acosFast(half inX)
{
	half x = abs(inX);
	half res = -0.156583f * x + (0.5 * PI);
	res *= sqrt(1.0f - x);
	return (inX >= 0) ? res : PI - res;
}

#define SQRT2PI 2.50663

//Gaussian Distribution for M term
inline half Hair_G(half B, half Theta)
{
	return exp(-0.5 * square(Theta) / (B*B)) / (SQRT2PI * B);
}


inline half3 SpecularFresnel(half3 F0, half vDotH)
{
	return F0 + (1.0f - F0) * pow(1 - vDotH, 5);
}

inline half3 SpecularFresnelLayer(half3 F0, half vDotH, half layer)
{
	half3 fresnel = SpecularFresnel(F0,  vDotH);
    return (fresnel * layer) / (1 + (layer-1) * fresnel);
}

// Yan, Ling-Qi, etc, "An efficient and practical near and far field fur reflectance model."
half3 FurBSDFYan(SurfaceOutputFur s, half3 L, float3 V, half3 N, half Shadow, half Backlit, half Area)
{
	half3 S = 0;

	const half VoL = dot(V, L);
	const half SinThetaL = dot(N, L);
	const half SinThetaV = dot(N, V);
	half cosThetaL = sqrt(max(0, 1 - SinThetaL * SinThetaL));
	half cosThetaV = sqrt(max(0, 1 - SinThetaV * SinThetaV));
	half CosThetaD = sqrt((1 + cosThetaL * cosThetaV + SinThetaV * SinThetaL) / 2.0);

	const half3 Lp = L - SinThetaL * N;
	const half3 Vp = V - SinThetaV * N;
	const half CosPhi = dot(Lp, Vp) * rsqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4);
	const half CosHalfPhi = sqrt(saturate(0.5 + 0.5 * CosPhi));

	half n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

	half Shift = 0.0499f;
	half Alpha[] =
	{
		-0.0998,//-Shift * 2,
		0.0499f,// Shift,
		0.1996  // Shift * 4
	};
	half B[] =
	{
		Area + square(s.Roughness),
		Area + square(s.Roughness) / 2,
		Area + square(s.Roughness) * 2
	};

	//float F0 = square((1 - 1.55f) / (1 + 1.55f));
	half F0 = 0.04652;//eta=1.55f

	half3 Tp;
	half Mp, Np, Fp, a, h, f;
	half ThetaH = SinThetaL + SinThetaV;
	// R
	Mp = Hair_G(B[0], ThetaH - Alpha[0]);
	Np = 0.25 * CosHalfPhi;
	Fp = SpecularFresnelLayer(F0, sqrt(saturate(0.5 + 0.5 * VoL)), s.Layer).x;
	S += (Mp * Np) * (Fp * lerp(1, Backlit, saturate(-VoL)));

	// TT
	Mp = Hair_G(B[1], ThetaH - Alpha[1]);
	a = rcp(n_prime);
	h = CosHalfPhi * (1 + a * (0.6 - 0.8 * CosPhi));
	f = SpecularFresnelLayer(F0, CosThetaD * sqrt(saturate(1 - h * h)), s.Layer).x;
	Fp = square(1 - f);
	half sinGammaTSqr = square((h * a));
	half sm = sqrt(saturate(square(s.Kappa)-sinGammaTSqr));
	half sc = sqrt(1 - sinGammaTSqr) - sm;
	Tp = pow(s.Albedo, 0.5 * sc / CosThetaD) * pow(s.MedulaAbsorb*s.MedulaScatter, 0.5 * sm / CosThetaD);
	Np = exp(-3.65 * CosPhi - 3.98);
	S += (Mp * Np) * (Fp * Tp) * Backlit;

	// TRT
	Mp = Hair_G(B[2], ThetaH - Alpha[2]);
	f = SpecularFresnelLayer(F0, CosThetaD * 0.5f, s.Layer).x;
	Fp = square(1 - f) * f;
	// assume h = sqrt(3)/2, calculate sm and sc
	sm = sqrt(saturate(square(s.Kappa)-0.75f));
	sc = 0.5f - sm;
	Tp = pow(s.Albedo, sc / CosThetaD) * pow(s.MedulaAbsorb*s.MedulaScatter, sm / CosThetaD);
	Np = exp((6.3f*CosThetaD+0.7f)*CosPhi-(5*CosThetaD+2));

	S += (Mp * Np) * (Fp * Tp);

	// TTs
	// hacking approximate Cm
	Mp = abs(cosThetaL)*0.5f;
	// still assume h = sqrt(3)/2
	Tp = pow(s.Albedo, (sc+1-s.Kappa)/(4*CosThetaD)) * pow(s.MedulaAbsorb, s.Kappa / (4*CosThetaD));
	// hacking approximate pre-integrated Dtts based on Cn
	Np = 0.05*(2*CosPhi*CosPhi - 1) + 0.16f;//0.05*std::cos(2*Phi) + 0.16f;

	S += (Mp * Np) * (f * Tp);

	//TRTs
	half phi = acosFast(CosPhi);
	// hacking approximate pre-integrated Dtrts based on Cn
	Np = 0.05f * cos(1.5*phi+1.7) + 0.18f;
	// still assume h = sqrt(3)/2
	Tp = pow(s.Albedo, (3*sc+1-s.Kappa)/(4*CosThetaD)) * pow(s.MedulaAbsorb, (2*sm+s.Kappa) / (4*CosThetaD)) * pow(s.MedulaScatter, sm/(8*CosThetaD));
	Fp = f * (1-f);

	S += (Mp * Np) * (Fp * Tp);

	return S;
}

half3 FurDiffuseKajiya(SurfaceOutputFur s, half3 L, float3 V, half3 N, half Shadow, half Backlit, half Area)
{
	half3 S = 0;
	half KajiyaDiffuse = 1 - abs(dot(N, L));

	half3 FakeNormal = SafeNormalize(V - N * dot(V, N));
	N = FakeNormal;

	// Hack approximation for multiple scattering.
	half Wrap = 1;
	half NoL = saturate((dot(N, L) + Wrap) / square(1 + Wrap));
	half DiffuseScatter = (1 / PI) * lerp(NoL, KajiyaDiffuse, 0.33);// *s.Metallic;
	half Luma = Luminance(s.Albedo);
	half3 ScatterTint = pow(s.Albedo / Luma, 1 - Shadow);
	S = sqrt(s.Albedo) * DiffuseScatter * ScatterTint;
	return S;
}

half3 FurBxDF(SurfaceOutputFur s, half3 N, float3 V, half3 L, half Shadow, half Backlit, half Area)
{
	half3 S = half3(0, 0, 0);

	S = FurBSDFYan(s, L, V, N, Shadow, Backlit, Area);
	S += FurDiffuseKajiya(s, L, V, N, Shadow, Backlit, Area);

	S = -min(-S, 0.0);

	return S;
}

#endif