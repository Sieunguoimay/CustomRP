using System;
using UnityEngine;
public class CustomRenderPipelineCamera:MonoBehaviour
{
    [SerializeField] private CameraSettings cameraSettings = default;

    public CameraSettings CameraSettings => cameraSettings ?? (cameraSettings = new CameraSettings());

}
