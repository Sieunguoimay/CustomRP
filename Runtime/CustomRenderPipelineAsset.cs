using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    [SerializeField] private CameraBufferSettings cameraBuffer = new CameraBufferSettings
    {
        allowHDR = true,
        renderScale = 1f,
        fxaa = new CameraBufferSettings.FXAA
        {
            fixedThreshold = 0.0833f,
            relativeThreshold = 0.166f,
            subpixelBlending = 0.75f,
        }
    };

    [SerializeField] private bool useDynamicBatching;
    [SerializeField] private bool useGPUInstancing;
    [SerializeField] private bool useSRPBatcher;
    [SerializeField] private bool useLightsPerObject;
    [SerializeField] private ShadowSettings shadows;
    [SerializeField] private PostFXSettings postFXSettings;

    public enum ColorLUTResolution
    {
        _16 = 16,
        _32 = 32,
        _64 = 64
    }

    [SerializeField] ColorLUTResolution colorLUTResolution = ColorLUTResolution._32;
    [SerializeField] private Shader cameraRendererShader = default;

    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderPipeline(cameraBuffer, useDynamicBatching, useGPUInstancing,
            useSRPBatcher, useLightsPerObject, shadows, postFXSettings, (int) colorLUTResolution,
            cameraRendererShader);
    }
}