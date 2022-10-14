#ifndef UNIVERSAL_MARSCHNER_HAIR_BSDF_INCLUDED
#define UNIVERSAL_MARSCHNER_HAIR_BSDF_INCLUDED

#define DEFAULT_HAIR_SPECULAR_VALUE 0.0465 // Hair is IOR 1.55
#define MATERIALFEATUREFLAGS_HAIR_MARSCHNER_SKIP_TT (1 << 16)
#define HAIR_H_TRT 0.86602540378
#define HAIR_H_TT  0.0

struct MarschnerHairSurfaceData
{
    half3	geomNormalWS;
    half3	hairStrandDirection;
    half3   normalWS;
    half    cuticleAngle;
    half    perceptualRadialSmoothness;
};

struct BSDFData
{
    uint materialFeatures;
    half ambientOcclusion;
    half specularOcclusion;
    half3 diffuseColor;
    half3 fresnel0;
    half3 normalWS;
    half3 geomNormalWS;
    half  perceptualRoughness;
    half3 hairStrandDirectionWS;
    half3 tangentWS;
    half3 bitangentWS;
    half  roughnessT;
    half  roughnessB;
    half3 absorption;
    half lightPathLength;
    half cuticleAngleR;
    half cuticleAngleTT;
    half cuticleAngleTRT;
    half roughnessR;
    half roughnessTT;
    half roughnessTRT;
    half roughnessRadial;
    half perceptualRoughnessRadial;
};

struct HairAngle
{
    half sinThetaI;
    half sinThetaO;
    half cosThetaI;
    half cosThetaO;
    half cosThetaD;
    half thetaH;
    half phiI;
    half phiO;
    half phi;
    half cosPhi;
    half sinThetaT;
    half cosThetaT;
};

void GetHairAngleWorld(half3 V, half3 L, half3 T, inout HairAngle angles)
{
    angles.sinThetaO = dot(T, V);
    angles.sinThetaI = dot(T, L);

    half thetaO = FastASin(angles.sinThetaO);
    half thetaI = FastASin(angles.sinThetaI);
    angles.thetaH = (thetaI + thetaO) * 0.5;

    angles.cosThetaD = cos((thetaO - thetaI) * 0.5);
    angles.cosThetaO = cos(thetaO);
    angles.cosThetaI = cos(thetaI);

    // Projection onto the normal plane, and since phi is the relative angle, we take the cosine in this projection.
    half3 VProj = V - angles.sinThetaO * T;
    half3 LProj = L - angles.sinThetaI * T;
    angles.cosPhi = dot(LProj, VProj) * rsqrt(dot(LProj, LProj) * dot(VProj, VProj) + 1e-5); // zero-div guard
    angles.phi = FastACos(angles.cosPhi);

    // Fixed for approximate human hair IOR
    angles.sinThetaT = angles.sinThetaO / 1.55;
    angles.cosThetaT = SafeSqrt(1 - Sq(angles.sinThetaT));
}

half3 D_LongitudinalScatteringGaussian(half3 thetaH, half3 beta)
{
    beta = max(beta, 1e-5); // zero-div guard

    const half sqrtTwoPi = 2.50662827463100050241;
    return rcp(beta * sqrtTwoPi) * exp(-Sq(thetaH) / (2 * Sq(beta)));
}

half3 DiffuseColorToAbsorption(half3 diffuseColor, half azimuthalRoughness)
{
    half beta  = azimuthalRoughness;
    half beta2 = beta  * beta;
    half beta3 = beta2 * beta;
    half beta4 = beta3 * beta;
    half beta5 = beta4 * beta;

    // Least squares fit of an inverse mapping between scattering parameters and scattering albedo.
    half denom = 5.969 - (0.215 * beta) + (2.532 * beta2) - (10.73 * beta3) + (5.574 * beta4) + (0.245 * beta5);

    half3 t = log(diffuseColor) / denom;
    return t * t;
}

half ModifiedRefractionIndex(half cosThetaD)
{
    // Original derivation of modified refraction index for arbitrary IOR.
    // float sinThetaD = sqrt(1 - Sq(cosThetaD));
    // return sqrt(Sq(eta) - Sq(sinThetaD)) / cosThetaD;

    // Karis approximation for the modified refraction index for human hair (1.55)
    return 1.19 / cosThetaD + (0.36 * cosThetaD);
}

void GetMarschnerAngle(half3 T, half3 V, half3 L,
                       out half thetaH, out half cosThetaD, out half cosPhi)
{
    // Optimized math for spherical coordinate angle derivation.
    // Ref: Light Scattering from Human Hair Fibers
    half sinThetaI = dot(T, L);
    half sinThetaR = dot(T, V);

    half thetaI = FastASin(sinThetaI);
    half thetaR = FastASin(sinThetaR);
    thetaH = (thetaI + thetaR) * 0.5;

    cosThetaD = cos((thetaR - thetaI) * 0.5);

    // Ref: Hair Animation and Rendering in the Nalu Demo
    // Projection onto the normal plane, and since phi is the relative angle, we take the cosine in this projection.
    half3 LProj = L - sinThetaI * T;
    half3 VProj = V - sinThetaR * T;
    cosPhi = dot(LProj, VProj) * rsqrt(dot(LProj, LProj) * dot(VProj, VProj));
}

// PreIntegrated average hair fiber scattering from HDRP.
half3 GetRoughenedAzimuthalScatteringDistribution(half phi, half cosThetaD, half beta)
{
    half X = (phi + TWO_PI) / FOUR_PI; // -2pi..2pi TO 0..1
    half Y = cosThetaD;
    half Z = beta;

    // TODO: It should be possible to reduce the domain of the integration to 0 -> HALF/PI as it repeats. This will save memory.
    return SAMPLE_TEXTURE3D_LOD(_PreIntegratedAverageHairFiberScattering, s_point_clamp_sampler, half3(X, Y, Z), 0).xyz; // half should be enough for a 64-sized Tex3D.
}

//MarschnerHairSurfaceData Struct in: com.unity.hairfx/Editor/ShaderGraph/UniversalPipeline/PhysicalHair/Includes/MarschnerHairSurfaceData.hlsl
BSDFData ConvertSurfaceDataToBSDFData(MarschnerHairSurfaceData hairSurfaceData, SurfaceData surfaceData)
{
    BSDFData bsdfData;
    ZERO_INITIALIZE(BSDFData, bsdfData);
    
    // IMPORTANT: All enable flags are statically know at compile time, so the compiler can do compile time optimization
    bsdfData.ambientOcclusion       = surfaceData.occlusion;

    bsdfData.diffuseColor           = surfaceData.albedo;

    bsdfData.normalWS               = hairSurfaceData.normalWS;
    bsdfData.geomNormalWS           = hairSurfaceData.geomNormalWS;
    bsdfData.perceptualRoughness    = PerceptualSmoothnessToPerceptualRoughness(surfaceData.smoothness);

    // This value will be override by the value in diffusion profile
    bsdfData.fresnel0               = DEFAULT_HAIR_SPECULAR_VALUE;

    // This is the hair tangent (which represents the hair strand direction, root to tip).
    bsdfData.hairStrandDirectionWS  = hairSurfaceData.hairStrandDirection;

    // Marschner
    // Note: Light Path Length is computed per-light.

    // Cuticle Angle
    const half cuticleAngle = radians(hairSurfaceData.cuticleAngle);
    bsdfData.cuticleAngleR   = -cuticleAngle;
    bsdfData.cuticleAngleTT  =  cuticleAngle * 0.5;
    bsdfData.cuticleAngleTRT =  cuticleAngle * 1.5;

    // Longitudinal Roughness
    const half roughnessL = PerceptualRoughnessToRoughness(bsdfData.perceptualRoughness);
    bsdfData.roughnessR   = roughnessL;
    bsdfData.roughnessTT  = roughnessL * 0.5;
    bsdfData.roughnessTRT = roughnessL * 2.0;

    // Azimuthal Roughness
    bsdfData.roughnessRadial = PerceptualSmoothnessToRoughness(hairSurfaceData.perceptualRadialSmoothness);
    bsdfData.perceptualRoughnessRadial = PerceptualSmoothnessToPerceptualRoughness(hairSurfaceData.perceptualRadialSmoothness);

    // Absorption
    bsdfData.absorption = DiffuseColorToAbsorption(surfaceData.albedo, bsdfData.roughnessRadial);

    return bsdfData;
}

// CBSDF Struct in: com.unity.render-pipeline.core/ShaderLibrary/BSDF.hlsl
CBSDF EvaluateBSDF(half3 V, half3 L, BSDFData bsdfData)
{
    CBSDF cbsdf;
    ZERO_INITIALIZE(CBSDF, cbsdf);

    half3 T = bsdfData.hairStrandDirectionWS;
    half3 N = bsdfData.normalWS;

#if _USE_LIGHT_FACING_NORMAL
    // The Kajiya-Kay model has a "built-in" transmission, and the 'NdotL' is always positive.
    half cosTL = dot(T, L);
    half sinTL = sqrt(saturate(1.0 - cosTL * cosTL));
    half NdotL = sinTL; // Corresponds to the cosine w.r.t. the light-facing normal
#else
    // Double-sided Lambert.
    half NdotL = dot(N, L);
#endif
    
    half clampedNdotL = saturate(NdotL);

    HairAngle angles;
    ZERO_INITIALIZE(HairAngle, angles);

    GetHairAngleWorld(V, L, T, angles);

    const half3 alpha = half3(
        bsdfData.cuticleAngleR,
        bsdfData.cuticleAngleTT,
        bsdfData.cuticleAngleTRT
    );

    const half3 beta = half3(
        bsdfData.roughnessR,
        bsdfData.roughnessTT,
        bsdfData.roughnessTRT
    );

    const half etaPrime = ModifiedRefractionIndex(angles.cosThetaD);

    const half3 mu = bsdfData.absorption;

    half3 F,Tr,S = 0;
    
    const half3 M = D_LongitudinalScatteringGaussian(angles.thetaH - alpha, beta);

    half3 A[3];

    // Fetch the preintegrated azimuthal distributions for each path
    const half3 D = GetRoughenedAzimuthalScatteringDistribution(angles.phi, angles.cosThetaD, bsdfData.perceptualRoughnessRadial);

    // Solve the first three lobes (R, TT, TRT).
    
    //R
    {
        // Attenuation for this path as proposed by d'Eon et al, replaced with a trig identity for cos half phi.
        A[0] = F_Schlick(bsdfData.fresnel0, sqrt(0.5 + 0.5 * dot(L,V)));

        //D = 0.25 * sqrt(0.5 + 0.5 * angles.cosPhi);
 
        S += M[0] * A[0] * D[0];
    }

    //TT
    {
        // Attenuation (Simplified for H = 0)
        half cosGamma0 = SafeSqrt(1 - Sq(HAIR_H_TT));
        half cosTheta = angles.cosThetaO * cosGamma0;
        F = F_Schlick(bsdfData.fresnel0, cosTheta);

        half sinGammaT = HAIR_H_TT / etaPrime;
        half cosGammaT = SafeSqrt(1 - Sq(sinGammaT));
        Tr = exp(-mu * (2 * cosGammaT / angles.cosThetaT));

        A[1] = Sq(1 - F) * Tr;
        
        //D = exp(-3.65 * angles.cosPhi - 3.98);
       
        S += M[1] * A[1] * D[1];
    }

    //TRT
    {
        // Attenutation (Simplified for H = ¡Ì3/2)
        half cosGammaO = SafeSqrt(1 - Sq(HAIR_H_TRT));
        half cosTheta  = angles.cosThetaO * cosGammaO;
        F = F_Schlick(bsdfData.fresnel0, cosTheta);

        half sinGammaT = HAIR_H_TRT / etaPrime;
        half cosGammaT = SafeSqrt(1 - Sq(sinGammaT));
        Tr = exp(-mu * (2 * cosGammaT / angles.cosThetaT));
        
        
        A[2] = Sq(1 - F) * F * Sq(Tr);
        
        //half scaleFactor = saturate(1.5 * (1 - bsdfData.roughnessRadial));
        //D = scaleFactor * exp(scaleFactor * (17.0 * angles.cosPhi - 16.78));
        
        S += M[2] * A[2] * D[2];
    }
    // TODO: Residual TRRT+ Lobe. (accounts for ~15% energy otherwise lost by the first three lobes).

    // This seems necesarry to match the reference.
    S *= INV_PI;
    
    // Transmission event is built into the model.
    // Some stubborn NaNs have cropped up due to the angle optimization, we suppress them here with a max for now.

    // NaN suppression is moved to "after CalculateFinalColor()".
    cbsdf.specR = S;//max(S, 0);

    // See "Analytic Tangent Irradiance Environment Maps for Anisotropic Surfaces".
    //cbsdf.diffR = clampedNdotL; // for URP
    cbsdf.diffR = Lambert() * clampedNdotL; // from HDRP
    
    return cbsdf;
}

// ref: HDRP ver.12 Hair.hlsl #1117
half3 EvaluateBSDF_Env(BSDFData bsdfData, InputData inputData)
{
    half3 R = reflect(-inputData.viewDirectionWS, inputData.normalWS);    
    half NoV = saturate(dot(bsdfData.normalWS, inputData.viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);
    
    half3 envLighting;
    
    half iblPerceptualRoughness = bsdfData.perceptualRoughness;
    half surfaceReduction = 1.0 / (iblPerceptualRoughness * iblPerceptualRoughness + 1.0);
    half3 indirectSpecular = GlossyEnvironmentReflection(R, 1, bsdfData.ambientOcclusion); // function in Lighting.hlsl
    indirectSpecular *= surfaceReduction * lerp(bsdfData.fresnel0, saturate(sqrt(iblPerceptualRoughness) + DEFAULT_HAIR_SPECULAR_VALUE), fresnelTerm);

    // Modify the roughness to approximate a larger area light source.
    bsdfData.roughnessR = saturate(bsdfData.roughnessR + 0.1);
    bsdfData.roughnessTRT = saturate(bsdfData.roughnessTRT + 0.1);

    // This sample is treated as a directional light source and we evaluate the BSDF with it directly.
    CBSDF cbsdf = EvaluateBSDF(inputData.viewDirectionWS, bsdfData.normalWS, bsdfData);
    
    envLighting = cbsdf.specR * indirectSpecular * PI ;

    return envLighting;
}

half4 LightingHairFX(MarschnerHairSurfaceData hairSurfaceData, SurfaceData surfaceData,InputData inputData)
{ 
#if defined(DEBUG_DISPLAY)
    half4 debugColor;
    
    BRDFData brdfData;
    ZERO_INITIALIZE(BRDFData,brdfData);
    
    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
#endif

    BSDFData bsdfData = ConvertSurfaceDataToBSDFData(hairSurfaceData, surfaceData);
    
    half4 shadowMask = CalculateShadowMask(inputData);
    
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
#if UNITY_VERSION >= 202220
    uint meshRenderingLayers = GetMeshRenderingLayer();
#else
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
#endif
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
  
    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    // Bake lighting (indirect lighting)
    half3 bakeDiffuseLighting = inputData.bakedGI * aoFactor.indirectAmbientOcclusion * bsdfData.diffuseColor;
    half3 indirectSpecularReflected = EvaluateBSDF_Env(bsdfData, inputData);

    lightingData.giColor = bakeDiffuseLighting + indirectSpecularReflected;

#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif        
    {
        // Direct lighting
        // This sample is treated as a directional light source and we evaluate the BSDF with it directly.
        CBSDF cbsdf = EvaluateBSDF(inputData.viewDirectionWS, mainLight.direction, bsdfData); 
        mainLight.color *= (mainLight.distanceAttenuation * mainLight.shadowAttenuation);
        lightingData.mainLightColor = (cbsdf.diffR * bsdfData.diffuseColor + cbsdf.specR) * mainLight.color;
    }
    
        // AdditionalLight Direct Light
#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    // We support directly Forward Plus for 2022.2, and skip support for the Clustered (experimental)
    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            CBSDF cbsdf = EvaluateBSDF(inputData.viewDirectionWS, light.direction, bsdfData);
            light.color *= (light.distanceAttenuation * light.shadowAttenuation);
            lightingData.additionalLightsColor += (cbsdf.diffR * bsdfData.diffuseColor + cbsdf.specR) * light.color;
        }
    }
    #endif
    
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif      
        {
            CBSDF cbsdf = EvaluateBSDF(inputData.viewDirectionWS, light.direction, bsdfData);
            light.color *= (light.distanceAttenuation * light.shadowAttenuation);
            lightingData.additionalLightsColor += (cbsdf.diffR * bsdfData.diffuseColor + cbsdf.specR) * light.color;
        }
    LIGHT_LOOP_END
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    lightingData.vertexLightingColor += inputData.vertexLighting * bsdfData.diffuseColor;
#endif

    // Some stubborn NaNs have cropped up due to the angle optimization.
    return max(CalculateFinalColor(lightingData, surfaceData.alpha), 0);
}

#endif
