#ifndef CUSTOM_CAMERA_RENDERER_PASS_INCLUDED
#define CUSTOM_CAMERA_RENDERER_PASS_INCLUDED
sampler2D _SourceTexture;

struct Varyings
{
    float4 positionCS_SS: SV_POSITION;
    float2 screenUV: VAR_SCREEN_UV;
};

Varyings DefaultPassVertex(uint vertexID: SV_VertexID)
{
    Varyings output;
    output.positionCS_SS = float4(
        vertexID <= 1 ? -1.0 : 3.0,
        vertexID == 1 ? 3.0 : -1.0,
        0.0, 1.0
    );
    output.screenUV = float2(
        vertexID <= 1 ? 0.0 : 2.0,
        vertexID == 1 ? 2.0 : 0.0
    );
    if (_ProjectionParams.x < 0.0)
    {
        output.screenUV.y = 1.0 - output.screenUV.y;
    }
    return output;
}

float4 CopyPassFragment(Varyings input):SV_TARGET
{
    return tex2Dlod(_SourceTexture, float4(input.screenUV, 0.0, 0.0));
}

float CopyDepthPassFragment(Varyings input):SV_DEPTH
{
    return tex2Dlod(_SourceTexture, float4(input.screenUV, 0.0, 0.0));
}
#endif
