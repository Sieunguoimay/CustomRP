#ifndef CUSTOM_FRAGMENT_INCLUDED
#define CUSTOM_FRAGMENT_INCLUDED

sampler2D _CameraDepthTexture;
sampler2D _CameraColorTexture;

float4 _CameraBufferSize;

struct Fragment
{
    float2 positionSS;
    float2 screenUV;
    float depth;
    float bufferDepth;
};

Fragment GetFragment(float4 positionSS)
{
    Fragment f;
    f.positionSS = positionSS.xy;
    f.screenUV = f.positionSS * _CameraBufferSize.xy;
    f.depth = IsOrthoGraphicCamera() ? OrthoGraphicDepthBufferToLinear(positionSS.z) : positionSS.w;
    f.bufferDepth = tex2Dlod(_CameraDepthTexture, float4(f.screenUV, 0.0, 0.0)).r;
    f.bufferDepth = IsOrthoGraphicCamera()
                        ? OrthoGraphicDepthBufferToLinear(f.bufferDepth)
                        : LinearEyeDepth(f.bufferDepth);
    return f;
}

float4 GetBufferColor(Fragment fragment, float2 uvOffset = float2(0.0, 0.0))
{
    float2 uv = fragment.screenUV + uvOffset;
    return tex2Dlod(_CameraColorTexture, float4(uv, 0.0, 0.0));
}
#endif
