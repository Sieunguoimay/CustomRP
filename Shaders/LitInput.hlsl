#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

sampler2D _BaseMap;
sampler2D _EmissionMap;
sampler2D _MaskMap;
sampler2D _DetailMap;
sampler2D _DetailNormalMap;
sampler2D _NormalMap;

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

struct InputConfig{
    Fragment fragment;
    float2 baseUV;
    float2 detailUV;
    bool useMask;
    bool useDetail;
};

InputConfig GetInputConfig(float4 positionSS,float2 baseUV, float2 detailUV = 0.0){
    InputConfig c;
    c.fragment = GetFragment(positionSS);
    c.baseUV = baseUV;
    c.detailUV = detailUV;
    c.useMask = false;
    c.useDetail = false;
    return c;
}

float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseST.xy * baseUV + baseST.zw;
}

float2 TransformDetailUV(float2 baseUV)
{
    float4 detailST = INPUT_PROP(_DetailMap_ST);
    return detailST.xy * baseUV + detailST.zw;
}

float4 GetDetail(InputConfig c)
{
    if(c.useDetail){
        float4 map = tex2D(_DetailMap, c.detailUV);
        return map * 2.0 - 1.0;
    }
    return 0.0;
}

float4 GetMask(InputConfig c)
{
    if(c.useMask)
        return tex2D(_MaskMap, c.baseUV);
    return 1.0;
}

float4 GetBase(InputConfig c)
{
    float4 map = tex2D(_BaseMap, c.baseUV);
    float4 color = INPUT_PROP(_BaseColor);

    if(c.useDetail){
        float detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
        float mask = GetMask(c).b;
        map.rgb = lerp(sqrt(map.rgb), detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
        map.rgb *= map.rgb;

    }

    return map * color;
}

float3 GetEmission(InputConfig c)
{
    float4 map = tex2D(_EmissionMap, c.baseUV);
    float4 color = INPUT_PROP(_EmissionColor);
    return map.rgb * color.rgb;
}

float GetCutoff(InputConfig c)
{
    return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig c)
{
    float metallic = INPUT_PROP(_Metallic);
    metallic *= GetMask(c).r;
    return metallic;
}

float GetOcclusion(InputConfig c)
{
    const float strength = INPUT_PROP(_Occlusion);
    const float occlusion = GetMask(c).g;
    return lerp(occlusion, 1.0, strength);
}

float GetSmoothness(InputConfig c)
{
    float smoothness = INPUT_PROP(_Smoothness);
    smoothness *= GetMask(c).a;

    if(c.useDetail){
        float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
        float mask = GetMask(c).b;
        smoothness = lerp(smoothness, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
    }

    return smoothness;
}

float GetFresnel(InputConfig c)
{
    return INPUT_PROP(_Fresnel);
}

float3 GetNormalTS(InputConfig c)
{
    float4 map = tex2D(_NormalMap,c.baseUV);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = UnpackNormalWithScale(map,scale);

    if(c.useDetail){

        map = tex2D(_DetailNormalMap,c.detailUV);
        scale = INPUT_PROP(_DetailNormalScale)*GetMask(c).b;
        float3 detail = UnpackNormalWithScale(map,scale);
        normal = BlendNormalRNM(normal,detail);

    }

    return normal;
}
#endif
