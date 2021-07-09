﻿using System;
using UnityEngine;

[Serializable]
public struct CameraBufferSettings
{
    public bool allowHDR;
    public bool copyColor, copyColorReflection, copyDepth, copyDepthReflection;

    [Range(CameraRenderer.renderScaleMin, CameraRenderer.renderScaleMax)]
    public float renderScale;

    [Serializable]
    public struct FXAA
    {
        public bool enabled;
        [Range(0.0312f, 0.0833f)] public float fixedThreshold;
        [Range(0.063f, 0.333f)] public float relativeThreshold;
        [Range(0f, 1f)] public float subpixelBlending;
    }

    public FXAA fxaa;
}