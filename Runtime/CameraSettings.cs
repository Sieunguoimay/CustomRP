using System;
using UnityEngine;

[Serializable]
public class CameraSettings
{
    public bool copyColor = true, copyDepth = true;

    public enum RenderScaleMode
    {
        Inherit,
        Multiply,
        Override
    };

    public RenderScaleMode renderScaleMode = RenderScaleMode.Inherit;

    [Range(CameraRenderer.renderScaleMin, CameraRenderer.renderScaleMax)]
    public float renderScale = 1f;

    public bool allowFXAA = false;
    public bool keepAlpha = false;

    public float GetRenderScale(float scale)
    {
        return renderScaleMode == RenderScaleMode.Inherit ? scale :
            renderScaleMode == RenderScaleMode.Override ? renderScale :
            renderScale * scale;
    }
}