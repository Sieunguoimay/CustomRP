using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

public partial class CustomRenderPipeline : RenderPipeline
{
    private readonly CameraRenderer _cameraRenderer;

    private readonly bool enableDynamicBatching;
    private readonly bool enableInstancing;
    private readonly bool useLightsPerObject;
    private ShadowSettings shadowSettings;
    private PostFXSettings postFXSettings;
    private int colorLUTResolution;
    private CameraBufferSettings cameraBufferSettings;

    public CustomRenderPipeline(CameraBufferSettings cameraBuffer, bool enableDynamicBatching, bool enableInstancing, bool useSRPBatcher,
        bool useLightsPerObject, ShadowSettings shadowSettings, PostFXSettings postFXSettings, int colorLUTResolution,
        Shader cameraRendererShader)
    {
        this.cameraBufferSettings = cameraBuffer;
        this.colorLUTResolution = colorLUTResolution;
        this.postFXSettings = postFXSettings;
        this.shadowSettings = shadowSettings;
        this.enableInstancing = enableInstancing;
        this.enableDynamicBatching = enableDynamicBatching;
        this.useLightsPerObject = useLightsPerObject;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        LODGroup.crossFadeAnimationDuration = 2f;
        InitializeForEditor();
        _cameraRenderer = new CameraRenderer(cameraRendererShader);
    }

    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach (var camera in cameras)
            _cameraRenderer.Render(context, camera,cameraBufferSettings, enableDynamicBatching, 
                enableInstancing, useLightsPerObject, shadowSettings, postFXSettings, colorLUTResolution);
    }
}

public partial class CameraRenderer
{
    private ScriptableRenderContext _context;
    private CullingResults cullingResults;
    private Camera _camera;
    
    public const float renderScaleMin = 0.01f, renderScaleMax = 2f;
    private const string BufferName = "Render Camera";
    private readonly CommandBuffer buffer = new CommandBuffer() { name = BufferName };
    private static readonly ShaderTagId UnlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
    private static readonly ShaderTagId LitShaderTagId = new ShaderTagId("CustomLit");
    private static readonly int cameraColorAttachmentId = Shader.PropertyToID("_CameraColorAttachment");
    private static readonly int cameraDepthAttachmentId = Shader.PropertyToID("_CameraDepthAttachment");
    private static readonly int cameraColorTextureId = Shader.PropertyToID("_CameraColorTexture");
    private static readonly int cameraDepthTextureId = Shader.PropertyToID("_CameraDepthTexture");
    private static readonly int sourceTextureId = Shader.PropertyToID("_SourceTexture");
    private static readonly int bufferSizeId = Shader.PropertyToID("_CameraBufferSize");

    private static bool copyTextureSupported = SystemInfo.copyTextureSupport > CopyTextureSupport.None;

    private Lighting lighting = new Lighting();
    private PostFXStack postFXStack = new PostFXStack();

    private bool useHDR, useScaledRendering;
    private bool useColorTexture, useDepthTexture, useIntermediateBuffer;

    private Material material;

    private CameraSettings defaultCameraSettings = new CameraSettings();

    private Texture2D missingTexture;

    private Vector2Int bufferSize;
    
    public CameraRenderer(Shader shader)
    {
        material = new Material(shader);
        material.hideFlags = HideFlags.HideAndDontSave;
        missingTexture = new Texture2D(1, 1) { hideFlags = HideFlags.HideAndDontSave, name = "Missing" };
        missingTexture.SetPixel(0, 0, Color.white * 0.5f);
        missingTexture.Apply(true, true);
    }

    public void Dispose()
    {
        if (Application.isPlaying)
        {
            Object.Destroy(material);
            Object.Destroy(missingTexture);
        }
        else
        {
            Object.DestroyImmediate(material);
            Object.DestroyImmediate(missingTexture);
        }

    }
    public void Render(ScriptableRenderContext context, Camera camera, CameraBufferSettings bufferSettings, bool enableDynamicBatching,
        bool enableInstancing, bool useLightsPerObject,
        ShadowSettings shadowSettings, PostFXSettings postFXSettings, int colorLUTResolution)
    {
        _context = context;
        _camera = camera;

        var crpCamera = _camera.GetComponent<CustomRenderPipelineCamera>();
        var cameraSettings = crpCamera ? crpCamera.CameraSettings : defaultCameraSettings;

        var renderScale = cameraSettings.GetRenderScale(bufferSettings.renderScale);
        useScaledRendering = Math.Abs(renderScale - 1f) > 0.01f;

        PrepareForSceneWindow();
        PrepareBuffer();
        if (!Cull(shadowSettings.maxDistance))
        {
            return;
        }
        useHDR = bufferSettings.allowHDR && _camera.allowHDR;
        if (useScaledRendering)
        {
            renderScale = Mathf.Clamp(renderScale, renderScaleMin, renderScaleMax);
            bufferSize.x = (int) (_camera.pixelWidth * renderScale);
            bufferSize.y = (int) (_camera.pixelHeight * renderScale);
        }
        else
        {
            bufferSize.x = _camera.pixelWidth;
            bufferSize.y = _camera.pixelHeight;
        }
        if (_camera.cameraType == CameraType.Reflection)
        {
            useDepthTexture = bufferSettings.copyDepthReflection;
            useColorTexture = bufferSettings.copyColorReflection;
        } else
        {
            useDepthTexture = bufferSettings.copyDepth & cameraSettings.copyDepth;
            useColorTexture = bufferSettings.copyColor & cameraSettings.copyColor;
        }
        useDepthTexture = true;
        buffer.BeginSample(SampleName);
        buffer.SetGlobalVector(bufferSizeId,new Vector4(1f/bufferSize.x,1f/bufferSize.y, bufferSize.x,bufferSize.y));
        ExecuteBuffer();
        
        lighting.Setup(context, cullingResults, shadowSettings, useLightsPerObject);

        bufferSettings.fxaa.enabled &= cameraSettings.allowFXAA;
        postFXStack.Setup(context, camera, bufferSize, postFXSettings, cameraSettings.keepAlpha, useHDR, colorLUTResolution, bufferSettings.fxaa);
        buffer.EndSample(SampleName);
        Setup();
        DrawVisibleGeometry(enableDynamicBatching, enableInstancing, useLightsPerObject);
        DrawUnsupportedShaders();
        DrawGizmosBeforeFX();
        if (postFXStack.IsActive)
        {
            postFXStack.Render(cameraColorAttachmentId);
        } else if (useIntermediateBuffer)
        {
            Draw(cameraColorAttachmentId, BuiltinRenderTextureType.CameraTarget);
            ExecuteBuffer();
        }
        DrawGizmosAfterFX();
        Cleanup();
        Submit();
    }
    private void Draw(RenderTargetIdentifier from, RenderTargetIdentifier to, bool isDepth = false)
    {
        buffer.SetGlobalTexture(sourceTextureId, from);
        buffer.SetRenderTarget(to, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.DrawProcedural(Matrix4x4.identity, material, isDepth ? 1 : 0, MeshTopology.Triangles, 3);
    }
    private bool Cull(float maxShadowDistance)
    {
        if (_camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            p.shadowDistance = Mathf.Min(maxShadowDistance, _camera.farClipPlane);
            cullingResults = _context.Cull(ref p);
            return true;
        }

        return false;
    }

    private void Setup()
    {
        _context.SetupCameraProperties(_camera);
        var clearFlags = _camera.clearFlags;

        useIntermediateBuffer = useScaledRendering|| useColorTexture|| useDepthTexture || postFXStack.IsActive;
        if (useIntermediateBuffer)
        {
            if (clearFlags > CameraClearFlags.Color)
            {
                clearFlags = CameraClearFlags.Color;
            }
            buffer.GetTemporaryRT(cameraColorAttachmentId, bufferSize.x, bufferSize.y, 0, FilterMode.Bilinear,
                useHDR?RenderTextureFormat.DefaultHDR: RenderTextureFormat.Default);
            buffer.GetTemporaryRT(cameraDepthAttachmentId, bufferSize.x, bufferSize.y,
                32, FilterMode.Point,RenderTextureFormat.Depth);
            buffer.SetRenderTarget(
                cameraColorAttachmentId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                cameraDepthAttachmentId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
                );
        }

        buffer.ClearRenderTarget(
            clearFlags <= CameraClearFlags.Depth,
            clearFlags == CameraClearFlags.Color,
            clearFlags == CameraClearFlags.Color ? _camera.backgroundColor.linear : Color.clear);
        buffer.BeginSample(SampleName);
        buffer.SetGlobalTexture(cameraColorTextureId, missingTexture);
        buffer.SetGlobalTexture(cameraDepthTextureId, missingTexture);
        ExecuteBuffer();
    }

    private void Cleanup()
    {
        lighting.Cleanup();
        if (useIntermediateBuffer)
        {
            buffer.ReleaseTemporaryRT(cameraColorAttachmentId);
            buffer.ReleaseTemporaryRT(cameraDepthAttachmentId);
            if (useColorTexture)
            {
                buffer.ReleaseTemporaryRT(cameraColorTextureId);
            }
            if (useDepthTexture)
            {
                buffer.ReleaseTemporaryRT(cameraDepthTextureId);
            }
        }
    }

    private void DrawVisibleGeometry(bool enableDynamicBatching, bool enableInstancing, bool useLightsPerObjects)
    {
        var lightsPerObjectFlags = useLightsPerObjects ? PerObjectData.LightData | PerObjectData.LightIndices : PerObjectData.None;
        var sortingSettings = new SortingSettings(_camera) {criteria = SortingCriteria.CommonOpaque};
        var drawingSettings = new DrawingSettings(UnlitShaderTagId, sortingSettings)
        {
            enableDynamicBatching = enableDynamicBatching,
            enableInstancing = enableInstancing,
            perObjectData = PerObjectData.ReflectionProbes
                            | PerObjectData.Lightmaps | PerObjectData.ShadowMask
                            | PerObjectData.LightProbe | PerObjectData.OcclusionProbe
                            | PerObjectData.LightProbeProxyVolume | PerObjectData.OcclusionProbeProxyVolume
                            | lightsPerObjectFlags
        };
        drawingSettings.SetShaderPassName(1, LitShaderTagId);

        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        _context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        // _context.DrawSkybox(_camera);
        if (useColorTexture || useDepthTexture)
        {
            CopyAttachments();
        }

        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        _context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    private void Submit()
    {
        buffer.EndSample(SampleName);
        ExecuteBuffer();
        _context.Submit();
    }

    private void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    private void CopyAttachments()
    {
        if (useColorTexture)
        {
            buffer.GetTemporaryRT(cameraColorTextureId, bufferSize.x, bufferSize.y, 0,
                FilterMode.Bilinear, useHDR?RenderTextureFormat.DefaultHDR:RenderTextureFormat.Default);
            if (copyTextureSupported)
            {
                buffer.CopyTexture(cameraColorAttachmentId, cameraColorTextureId);
            }
            else
            {
                Draw(cameraColorAttachmentId, cameraColorTextureId);
            }
        }
        if (useDepthTexture)
        {
            buffer.GetTemporaryRT(cameraDepthTextureId,bufferSize.x, bufferSize.y,32, FilterMode.Point, RenderTextureFormat.Depth);
            if (copyTextureSupported)
            {
                buffer.CopyTexture(cameraDepthAttachmentId, cameraDepthTextureId);
            }
            else
            {
                Draw(cameraDepthAttachmentId, cameraDepthTextureId, true);
            }
        }
        if (!copyTextureSupported)
        {
            buffer.SetRenderTarget(
                cameraColorAttachmentId, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store,
                cameraDepthAttachmentId, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store
                );
        }
        ExecuteBuffer();

    }
}
