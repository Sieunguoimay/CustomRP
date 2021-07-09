#ifndef LIT_PASS_HLSL
#define LIT_PASS_HLSL
#include"../ShaderLibrary/Surface.hlsl"
#include"../ShaderLibrary/Shadows.hlsl"
#include"../ShaderLibrary/Light.hlsl"
#include"../ShaderLibrary/BRDF.hlsl"
#include"../ShaderLibrary/GI.hlsl"
#include"../ShaderLibrary/Lighting.hlsl"

// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);
// UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
// UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
// UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
// UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
// UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
// UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes
{
    float3 positionOS:POSITION;
    float3 normalOS: NORMAL;
#if defined(_NORMAL_MAP)
    float4 tangentOS:TANGENT;
#endif
    float2 baseUV: TEXCOORD0;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS_SS:POSITION;
    float3 positionWS: VAR_POSITION;
    float3 normalWS: VAR_NORMAL;
    float4 tangentWS:VAR_TANGENT;
    float2 baseUV: VAR_BASE_UV;
#if defined(_DETAIL_MAP)
    float2 detailUV: VAR_DETAIL_UV;
#endif
    GI_VARYINGS_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input) //:SV_POSITION
{
    Varyings output;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    TRANSFER_GI_DATA(input, output);

    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS_SS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
#if defined(_NORMAL_MAP)
    output.tangentWS = float4(UnityObjectToWorldDir(input.tangentOS.xyz),
                              input.tangentOS.w * unity_WorldTransformParams.w);
#endif

    output.baseUV = TransformBaseUV(input.baseUV);
#if defined(_DETAIL_MAP)
    output.detailUV = TransformDetailUV(input.baseUV);
#endif
    return output;
}

float4 LitPassFragment(Varyings input):SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    InputConfig config = GetInputConfig(input.positionCS_SS,input.baseUV);

    ClipLOD(config.fragment, unity_LODFade.x);
    #if defined(_MASK_MAP)
    config.useMask = true;
    #endif
    #if defined(_DETAIL_MAP)
    config.detailUV = input.detailUV;
    config.useDetail = true;
    #endif
    const float4 base = GetBase(config);
    #if defined(_CLIPPING)
    clip(base.a - GetCutoff(config));
    #endif

    Surface surface;
    surface.position = input.positionWS;
#if defined(_NORMAL_MAP)
    surface.normal = NormalTangentToWorld(GetNormalTS(config), input.normalWS, input.tangentWS);
    surface.interpolatedNormal=normalize(input.normalWS);
#else
    surface.normal = normalize(input.normalWS);
    surface.interpolatedNormal = surface.normal;
#endif
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.color = base.rgb;
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.alpha = base.a;
    surface.metallic = GetMetallic(config);
    surface.occlusion = GetOcclusion(config);
    surface.smoothness = GetSmoothness(config);
    surface.fresnelStrength = GetFresnel(config);
    surface.dither = InterleavedGradientNoise(config.fragment.positionSS);

    #if defined(_PREMULTIPLY_ALPHA)
    const BRDF brdf = GetBRDF(surface, true);
    #else
    const BRDF brdf = GetBRDF(surface);
    #endif

    const GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);

    float3 color = GetLighting(surface, brdf, gi);

    color += GetEmission(config);

    return float4(color, surface.alpha);
}
#endif
