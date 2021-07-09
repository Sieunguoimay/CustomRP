using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

public partial class CustomRenderPipeline
{
    partial void InitializeForEditor();
    partial void DisposeForEditor();

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        //UnityEngine.Experimental.GlobalIllumination.Lightmapping.ResetDelegate();
        DisposeForEditor();
        _cameraRenderer.Dispose();
    }

#if UNITY_EDITOR
    partial void InitializeForEditor()
    {
        UnityEngine.Experimental.GlobalIllumination.Lightmapping.SetDelegate(lightsDelegate);
    }

    partial void DisposeForEditor()
    {
        UnityEngine.Experimental.GlobalIllumination.Lightmapping.ResetDelegate();
    }

    static UnityEngine.Experimental.GlobalIllumination.Lightmapping.RequestLightsDelegate lightsDelegate = (Light[] lights, NativeArray<LightDataGI> output) => {
        var lightData = new LightDataGI();
        for (int i = 0; i < lights.Length; i++)
        {
            Light light = lights[i];
            switch (light.type)
            {
                case UnityEngine.LightType.Directional:
                    var directionalLight = new DirectionalLight();
                    LightmapperUtils.Extract(light, ref directionalLight);
                    lightData.Init(ref directionalLight);
                    break;
                case UnityEngine.LightType.Point:
                    var pointLight = new PointLight();
                    LightmapperUtils.Extract(light, ref pointLight);
                    lightData.Init(ref pointLight);
                    break;
                case UnityEngine.LightType.Spot:
                    var spotLight = new SpotLight();
                    LightmapperUtils.Extract(light, ref spotLight);
                    spotLight.innerConeAngle = light.innerSpotAngle * Mathf.Deg2Rad;
                    spotLight.angularFalloff = AngularFalloffType.AnalyticAndInnerAngle;
                    lightData.Init(ref spotLight);
                    break;
                case UnityEngine.LightType.Area:
                    var areaLight = new RectangleLight();
                    areaLight.mode = LightMode.Baked;
                    LightmapperUtils.Extract(light, ref areaLight);
                    lightData.Init(ref areaLight);
                    break;
                default:
                    lightData.InitNoBake(light.GetInstanceID());
                    break;
            }
            lightData.falloff = FalloffType.InverseSquared;
            output[i] = lightData;
        }
    };
#endif
}


public partial class CameraRenderer
{
#if UNITY_EDITOR
    private static Material _errorMaterial;

    private static Material ErrorMaterial =>
        _errorMaterial ? _errorMaterial : (_errorMaterial = new Material(Shader.Find("Hidden/InternalErrorShader")));

    private static readonly ShaderTagId[] LegacyShaderTagIds =
    {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM"),
    };
#endif
#if UNITY_EDITOR
    partial void DrawUnsupportedShaders()
    {
        var sortingSettings = new SortingSettings(_camera);
        var drawingSettings = new DrawingSettings(LegacyShaderTagIds[0], sortingSettings)
        {
            overrideMaterial = ErrorMaterial
        };
        var filteringSettings = FilteringSettings.defaultValue;
        for (int i = 1; i < LegacyShaderTagIds.Length; i++)
        {
            drawingSettings.SetShaderPassName(i, LegacyShaderTagIds[i]);
        }

        _context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    partial void DrawGizmosBeforeFX()
    {
        if (Handles.ShouldRenderGizmos())
        {
            if (useIntermediateBuffer)
            {
                Draw(cameraDepthAttachmentId, BuiltinRenderTextureType.CameraTarget, true);
                ExecuteBuffer();
            }
            _context.DrawGizmos(_camera, GizmoSubset.PreImageEffects);
        }
    }
    partial void DrawGizmosAfterFX()
    {
        if (Handles.ShouldRenderGizmos())
        {
            _context.DrawGizmos(_camera, GizmoSubset.PostImageEffects);
        }
    }

    partial void PrepareForSceneWindow()
    {
        if (_camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(_camera);
            useScaledRendering = false;
        }
    }

    partial void PrepareBuffer()
    {
        Profiler.BeginSample("Editor");
        SampleName = _camera.name;
        buffer.name = _camera.name;
        Profiler.EndSample();
    }

    private string SampleName { get; set; }
#else
    private string SampleName => BufferName;
#endif
    partial void DrawUnsupportedShaders();
    partial void DrawGizmosBeforeFX();
    partial void DrawGizmosAfterFX();
    partial void PrepareForSceneWindow();
    partial void PrepareBuffer();
}
