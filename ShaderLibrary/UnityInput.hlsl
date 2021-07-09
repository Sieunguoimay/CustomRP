#ifndef UNITY_INPUT_HLSL
#define UNITY_INPUT_HLSL
#include <HLSLSupport.cginc>
#include <UnityShaderVariables.cginc>
#include <UnityShaderUtilities.cginc>
#include <UnityInstancing.cginc>
#include <UnityGlobalIllumination.cginc>
// float4x4 unity_MatrixVP;
// float3 _WorldSpaceCameraPos;
// 
CBUFFER_START(UnityPerDraw)
// float4x4 unity_ObjectToWorld;
// float4x4 unity_WorldToObject;
// float4 unity_LODFade;
// float4 unity_WorldTransformParams;
float4 unity_LightData;
float4 unity_LightIndices[2];
CBUFFER_END

#endif