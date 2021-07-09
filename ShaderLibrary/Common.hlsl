#if defined(_SHADOW_MASK_ALWAYS)||defined(_SHADOW_MASK_DISTANCE)
#define SHADOW_SHADOWMASK
#endif
#include <UnityCG.cginc>
#ifndef COMMON_HLSL
#define COMMON_HLSL
#include"UnityInput.hlsl"


bool IsOrthoGraphicCamera()
{
    return unity_OrthoParams.w;
}

float OrthoGraphicDepthBufferToLinear(float rawDepth)
{
    #if UNITY_REVERSED_Z
    rawDepth = 1.0 - rawDepth;
    #endif
    return (_ProjectionParams.z - _ProjectionParams.y) * rawDepth + _ProjectionParams.y;
}

#include"Fragment.hlsl"

#define HALF_MAX        65504.0 // (2 - 2^-10) * 2^15
#define HALF_MAX_MINUS1 65472.0 // (2 - 2^-9) * 2^15
#define EPSILON         1.0e-4
#define PI              3.14159265359
#define TWO_PI          6.28318530718
#define FOUR_PI         12.56637061436
#define INV_PI          0.31830988618F
#define INV_TWO_PI      0.15915494309
#define INV_FOUR_PI     0.07957747155
#define HALF_PI         1.57079632679
#define INV_HALF_PI     0.636619772367

#define FLT_EPSILON     1.192092896e-07 // Smallest positive number, such that 1.0 + FLT_EPSILON != 1.0
#define FLT_MIN         1.175494351e-38 // Minimum representable positive floating-point number
#define FLT_MAX         3.402823466e+38 // Maximum representable floating-point number

float3 TransformObjectToWorld(float3 positionOS)
{
    return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
}

float4 TransformWorldToHClip(float3 positionWS)
{
    return mul(unity_MatrixVP, float4(positionWS, 1.0));
}

float3 TransformObjectToWorldNormal(float3 normalOS)
{
    return mul(unity_ObjectToWorld, float4(normalOS, 0.0)).xyz;
}

float3 TransformWorldToView(float3 positionWS)
{
    return mul(unity_MatrixV, float4(positionWS, 1.0)).xyz;
}

float Square(float v)
{
    return v * v;
}

float DistanceSquared(float3 pA, float3 pB)
{
    return dot(pA - pB, pA - pB);
}

float InterleavedGradientNoise(float2 n)
{
    float f = 0.06711056 * n.x + 0.00583715 * n.y;
    return frac(52.9829189 * frac(f));
}

#define TEXTURE2D(textureName)                Texture2D textureName
#define TEXTURE3D(textureName)                Texture3D textureName
#define SAMPLER(samplerName)                  SamplerState samplerName
#define TEXTURE2D_ARRAY(textureName)          Texture2DArray textureName

#define TEXTURE2D_PARAM(textureName, samplerName)                 TEXTURE2D(textureName),         SAMPLER(samplerName)
#define TEXTURE3D_PARAM(textureName, samplerName)                 TEXTURE3D(textureName),         SAMPLER(samplerName)
#define SAMPLE_TEXTURE2D(textureName, samplerName, coord2)                               textureName.Sample(samplerName, coord2)
#define TEXTURE2D_ARGS(textureName, samplerName)                textureName, samplerName
#define TEXTURE3D_ARGS(textureName, samplerName)                textureName, samplerName
#define SAMPLE_TEXTURE3D(textureName, samplerName, coord3)                               textureName.Sample(samplerName, coord3)

#define TEXTURE2D_ARRAY_PARAM(textureName, samplerName)           TEXTURE2D_ARRAY(textureName),   SAMPLER(samplerName)
#define TEXTURE2D_ARRAY_ARGS(textureName, samplerName)          textureName, samplerName
#define SAMPLE_TEXTURE2D_ARRAY(textureName, samplerName, coord2, index)                  textureName.Sample(samplerName, float3(coord2, index))

#if defined(UNITY_DOTS_INSTANCING_ENABLED)

#define TEXTURE2D_LIGHTMAP_PARAM TEXTURE2D_ARRAY_PARAM
#define TEXTURE2D_LIGHTMAP_ARGS TEXTURE2D_ARRAY_ARGS
#define SAMPLE_TEXTURE2D_LIGHTMAP SAMPLE_TEXTURE2D_ARRAY
#define LIGHTMAP_EXTRA_ARGS float2 uv, float slice
#define LIGHTMAP_EXTRA_ARGS_USE uv, slice

#else
#define TEXTURE2D_LIGHTMAP_PARAM TEXTURE2D_PARAM
#define TEXTURE2D_LIGHTMAP_ARGS TEXTURE2D_ARGS
#define SAMPLE_TEXTURE2D_LIGHTMAP SAMPLE_TEXTURE2D
#define LIGHTMAP_EXTRA_ARGS float2 uv
#define LIGHTMAP_EXTRA_ARGS_USE uv
#endif

#define LIGHTMAP_HDR_MULTIPLIER float(1.0)
#define LIGHTMAP_HDR_EXPONENT float(1.0)

float3 SampleSingleLightmap(
    TEXTURE2D_LIGHTMAP_PARAM(lightmapTex, lightmapSampler), LIGHTMAP_EXTRA_ARGS, float4 transform, bool encodedLightmap,
    float4 decodeInstructions)
{
    // transform is scale and bias
    uv = uv * transform.xy + transform.zw;
    float3 illuminance = float3(0.0, 0.0, 0.0);
    // Remark: baked lightmap is RGBM for now, dynamic lightmap is RGB9E5
    if (encodedLightmap)
    {
        float4 encodedIlluminance = SAMPLE_TEXTURE2D_LIGHTMAP(lightmapTex, lightmapSampler, LIGHTMAP_EXTRA_ARGS_USE).
            rgba;
        illuminance = DecodeLightmap(encodedIlluminance, decodeInstructions);
    }
    else
    {
        illuminance = SAMPLE_TEXTURE2D_LIGHTMAP(lightmapTex, lightmapSampler, LIGHTMAP_EXTRA_ARGS_USE).rgb;
    }
    return illuminance;
}

#if HAS_HALF
half3 SampleSH9(half4 SHCoefficients[7], half3 N)
{
    half4 shAr = SHCoefficients[0];
    half4 shAg = SHCoefficients[1];
    half4 shAb = SHCoefficients[2];
    half4 shBr = SHCoefficients[3];
    half4 shBg = SHCoefficients[4];
    half4 shBb = SHCoefficients[5];
    half4 shCr = SHCoefficients[6];

    // Linear + constant polynomial terms
    half3 res = SHEvalLinearL0L1(N, shAr, shAg, shAb);

    // Quadratic polynomials
    res += SHEvalLinearL2(N, shBr, shBg, shBb, shCr);

#ifdef UNITY_COLORSPACE_GAMMA
    res = LinearToSRGB(res);
#endif

    return res;
}
#endif


#if UNITY_LIGHT_PROBE_PROXY_VOLUME
void SampleProbeVolumeSH4(TEXTURE3D_PARAM(SHVolumeTexture, SHVolumeSampler), float3 positionWS, float3 normalWS, float3 backNormalWS, float4x4 WorldToTexture,
                            float transformToLocal, float texelSizeX, float3 probeVolumeMin, float3 probeVolumeSizeInv,
                            inout float3 bakeDiffuseLighting, inout float3 backBakeDiffuseLighting)
{
    bakeDiffuseLighting += SHEvalLinearL0L1_SampleProbeVolume(float4(normalWS, 1.0),positionWS);
    backBakeDiffuseLighting += SHEvalLinearL0L1(float4(backNormalWS, 1.0));
}

// Just a shortcut that call function above
float3 SampleProbeVolumeSH4(TEXTURE3D_PARAM(SHVolumeTexture, SHVolumeSampler), float3 positionWS, float3 normalWS, float4x4 WorldToTexture,
                                float transformToLocal, float texelSizeX, float3 probeVolumeMin, float3 probeVolumeSizeInv)
{
    float3 backNormalWSUnused = 0.0;
    float3 bakeDiffuseLighting = 0.0;
    float3 backBakeDiffuseLightingUnused = 0.0;
    SampleProbeVolumeSH4(TEXTURE3D_ARGS(SHVolumeTexture, SHVolumeSampler), positionWS, normalWS, backNormalWSUnused, WorldToTexture,
                            transformToLocal, texelSizeX, probeVolumeMin, probeVolumeSizeInv,
                            bakeDiffuseLighting, backBakeDiffuseLightingUnused);
    return bakeDiffuseLighting;
}

float4 SampleProbeOcclusion(TEXTURE3D_PARAM(SHVolumeTexture, SHVolumeSampler), float3 positionWS, float4x4 WorldToTexture,
                            float transformToLocal, float texelSizeX, float3 probeVolumeMin, float3 probeVolumeSizeInv)
{
    float3 position = (transformToLocal == 1.0) ? mul(WorldToTexture, float4(positionWS, 1.0)).xyz : positionWS;
    float3 texCoord = (position - probeVolumeMin) * probeVolumeSizeInv.xyz;

    // Sample fourth texture in the atlas
// We need to compute proper U coordinate to sample.
    // Clamp the coordinate otherwize we'll have leaking between ShB coefficients and Probe Occlusion(Occ) info
    texCoord.x = max(texCoord.x * 0.25 + 0.75, 0.75 + 0.5 * texelSizeX);

    return SAMPLE_TEXTURE3D(SHVolumeTexture, SHVolumeSampler, texCoord);
}
#endif

#ifndef UNITY_SPECCUBE_LOD_STEPS
#define UNITY_SPECCUBE_LOD_STEPS 6
#endif
// Util image based lighting
//-----------------------------------------------------------------------------

// The *approximated* version of the non-linear remapping. It works by
// approximating the cone of the specular lobe, and then computing the MIP map level
// which (approximately) covers the footprint of the lobe with a single texel.
// Improves the perceptual roughness distribution.
float PerceptualRoughnessToMipmapLevel(float perceptualRoughness, uint mipMapCount)
{
    perceptualRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);

    return perceptualRoughness * mipMapCount;
}

float PerceptualRoughnessToMipmapLevel(float perceptualRoughness)
{
    return PerceptualRoughnessToMipmapLevel(perceptualRoughness, UNITY_SPECCUBE_LOD_STEPS);
}

void ClipLOD(Fragment fragment, float fade)
{
    #if defined(LOD_FADE_CROSSFADE)
    float dither = InterleavedGradientNoise(fragment.positionSS);
    clip(fade + (fade<0.0?dither:-dither));
    #endif
}
#endif

float GetOddNegativeScale()
{
    // FIXME: We should be able to just return unity_WorldTransformParams.w, but it is not
    // properly set at the moment, when doing ray-tracing; once this has been fixed in cpp,
    // we can revert back to the former implementation.
    return unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0;
}

float3x3 CreateTangentToWorld(float3 normal, float3 tangent, float flipSign)
{
    // For odd-negative scale transforms we need to flip the sign
    float sgn = flipSign * GetOddNegativeScale();
    float3 bitangent = cross(normal, tangent) * sgn;

    return float3x3(tangent, bitangent, normal);
}

float3 TransformTangentToWorld(float3 dirTS, float3x3 tangentToWorld)
{
    // Note matrix is in row major convention with left multiplication as it is build on the fly
    return mul(dirTS, tangentToWorld);
}

float3 NormalTangentToWorld(float3 normalTS, float3 normalWS, float4 tangentWS)
{
    float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
    return TransformTangentToWorld(normalTS, tangentToWorld);
}

float4x4 GetObjectToWorldMatrix()
{
    return UNITY_MATRIX_M;
}

inline float3 SafeNormalize(float3 inVec)
{
    float dp3 = max(0.001f, dot(inVec, inVec));
    return inVec * rsqrt(dp3);
}

float Min3(float a, float b, float c)
{
    return min(min(a, b), c);
}

float Max3(float a, float b, float c)
{
    return max(max(a, b), c);
}

// Normalize to support uniform scaling
float3 TransformObjectToWorldDir(float3 dirOS, bool doNormalize = true)
{
    #ifndef SHADER_STAGE_RAY_TRACING
    float3 dirWS = mul((float3x3)GetObjectToWorldMatrix(), dirOS);
    #else
    float3 dirWS = mul((float3x3)ObjectToWorld3x4(), dirOS);
    #endif
    if (doNormalize)
        return SafeNormalize(dirWS);

    return dirWS;
}

float3 BlendNormalRNM(float3 n1, float3 n2)
{
    float3 t = n1.xyz + float3(0.0, 0.0, 1.0);
    float3 u = n2.xyz * float3(-1.0, -1.0, 1.0);
    float3 r = (t / t.z) * dot(t, u) - u;
    return r;
}

#define CUBEMAPFACE_POSITIVE_X 0
#define CUBEMAPFACE_NEGATIVE_X 1
#define CUBEMAPFACE_POSITIVE_Y 2
#define CUBEMAPFACE_NEGATIVE_Y 3
#define CUBEMAPFACE_POSITIVE_Z 4
#define CUBEMAPFACE_NEGATIVE_Z 5

#ifndef INTRINSIC_CUBEMAP_FACE_ID
float CubeMapFaceID(float3 dir)
{
    float faceID;

    if (abs(dir.z) >= abs(dir.x) && abs(dir.z) >= abs(dir.y))
    {
        faceID = (dir.z < 0.0) ? CUBEMAPFACE_NEGATIVE_Z : CUBEMAPFACE_POSITIVE_Z;
    }
    else if (abs(dir.y) >= abs(dir.x))
    {
        faceID = (dir.y < 0.0) ? CUBEMAPFACE_NEGATIVE_Y : CUBEMAPFACE_POSITIVE_Y;
    }
    else
    {
        faceID = (dir.x < 0.0) ? CUBEMAPFACE_NEGATIVE_X : CUBEMAPFACE_POSITIVE_X;
    }

    return faceID;
}
#endif // INTRINSIC_CUBEMAP_FACE_ID
