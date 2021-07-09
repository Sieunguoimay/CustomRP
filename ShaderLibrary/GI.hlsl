#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED
#include"ThirdParty/Colors.hlsl"
struct GI
{
    float3 diffuse;
    float3 specular;
    ShadowMask shadowMask;
};

float3 SampleLightmap(float2 lightmapUV)
{
    #if defined(LIGHTMAP_ON)
    return SampleSingleLightmap(
        TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightmapUV, float4(1.0, 1.0, 0.0, 0.0),
    #if defined(UNITY_LIGHTMAP_FULL_HDR)
    false,
    #else
        true,
    #endif
        float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0));
    #else
    return 0.0;
    #endif
}

float3 SampleLightProbe(Surface surfaceWS)
{
    #if defined(LIGHTMAP_ON)
        return 0.0;
    #else

    #if(UNITY_LIGHT_PROBE_PROXY_VOLUME)
    if(unity_ProbeVolumeParams.x)
    {
        return SampleProbeVolumeSH4(TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
            surfaceWS.position, surfaceWS.normal,
            unity_ProbeVolumeWorldToObject,
            unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
            unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz);
    }else
    {
        return max(0.0, SampleSH9(surfaceWS.normal));
    }
    #else
    return max(0.0, SampleSH9(surfaceWS.normal));
    #endif

    #endif
}

float4 SampleBakedShadows(float2 lightMapUV, Surface surfaceWS)
{
    #if defined(LIGHTMAP_ON)
        return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
    #else
    #if(UNITY_LIGHT_PROBE_PROXY_VOLUME)
        if(unity_ProbeVolumeParams.x){
            return SampleProbeOcclusion(TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
            surfaceWS.position,
            unity_ProbeVolumeWorldToObject,
            unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
            unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz);
        }else{
            return unity_ProbesOcclusion;
        }
    #endif

    #endif
}

float3 SampleEnvironment(Surface surfaceWS, BRDF brdf)
{
    float3 uvw = reflect(-surfaceWS.viewDirection, surfaceWS.normal);
    float mip = PerceptualRoughnessToMipmapLevel(brdf.perceptualRoughness);
    float4 environment = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, uvw, mip);
    float3 color = DecodeHDR(environment, unity_SpecCube0_HDR);
    return color;
}

GI GetGI(float2 lightUV, Surface surfaceWS, BRDF brdf)
{
    GI gi;
    gi.diffuse = SampleLightmap(lightUV) + SampleLightProbe(surfaceWS);
    gi.specular = SampleEnvironment(surfaceWS, brdf);
    gi.shadowMask.always = false;
    gi.shadowMask.distance = false;
    gi.shadowMask.shadows = 1.0;
    #if defined(_SHADOW_MASK_ALWAYS)
        gi.shadowMask.always = true;
        gi.shadowMask.shadows = SampleBakedShadows(lightUV, surfaceWS);
    #elif defined(_SHADOW_MASK_DISTANCE)
        gi.shadowMask.distance = true;
        gi.shadowMask.shadows = SampleBakedShadows(lightUV, surfaceWS);
    #endif
    return gi;
}
#if defined(LIGHTMAP_ON)
#define GI_ATTRIBUTE_DATA float2 lightMapUV: TEXCOORD1;
#define GI_VARYINGS_DATA float2 lightMapUV: VAR_LIGHT_MAP_UV;
#define TRANSFER_GI_DATA(input, output) \
    output.lightMapUV = input.lightMapUV* \
    unity_LightmapST.xy + unity_LightmapST.zw;
#define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
#define GI_ATTRIBUTE_DATA
#define GI_VARYINGS_DATA
#define TRANSFER_GI_DATA(input, output)
#define GI_FRAGMENT_DATA(input) 0.0
#endif

#endif
