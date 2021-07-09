#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#define MIN_REFLECTIVITY 0.04

struct BRDF
{
    float3 diffuse;
    float3 specular;
    float roughness;
    float perceptualRoughness;
    float fresnel;
};

float OneMinusReflectivity(float metallic)
{
    const float range = 1.0 - MIN_REFLECTIVITY;
    return (1.0 - metallic) * range;
}
/*
float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
    return perceptualRoughness * perceptualRoughness;
}

float SmoothnessToPerceptualRoughness(float smoothness)
{
    return (1 - smoothness);
}
*/
float SpecularStrength(Surface surface, BRDF brdf, Light light)
{
    const float3 h = normalize(light.direction + surface.viewDirection);
    const float nh2 = Square(saturate(dot(surface.normal, h)));
    const float lh2 = Square(saturate(dot(light.direction, h)));
    const float r2 = Square(brdf.roughness);
    const float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
    const float normalization = brdf.roughness * 4.0 + 2.0;
    return r2 / (d2 * max(.1, lh2) * normalization);
}

float3 DirectBRDF(Surface surface, BRDF brdf, Light light)
{
    return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

float3 IndirectBRDF(Surface surface, BRDF brdf, float3 diffuse, float3 specular)
{
    const float fresnelStrength = surface.fresnelStrength *
        pow(1.0 - saturate(dot(surface.normal, surface.viewDirection)), 4);
    float3 reflection = specular * lerp(brdf.specular, brdf.fresnel, fresnelStrength);
    reflection /= brdf.roughness * brdf.roughness + 1.0;
    return (diffuse * brdf.diffuse + reflection) * surface.occlusion;
}

BRDF GetBRDF(Surface surface, bool applyAlphaToDiffuse = false)
{
    BRDF brdf;
    const float oneMinusRefectivity = OneMinusReflectivity(surface.metallic);
    brdf.diffuse = surface.color * oneMinusRefectivity;
    if (applyAlphaToDiffuse)
    {
        brdf.diffuse *= surface.alpha;
    }
    brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);
    brdf.perceptualRoughness = SmoothnessToPerceptualRoughness(surface.smoothness);
    brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);
    brdf.fresnel = saturate(surface.smoothness + 1.0 - oneMinusRefectivity);
    return brdf;
}
#endif
