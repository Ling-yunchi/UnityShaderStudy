using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DepthCamera : MonoBehaviour
{
    private Camera cam;
    void Awake()
    {
        cam = GetComponent<Camera>();
    }
    
    void Start()
    {
        cam.depthTextureMode = DepthTextureMode.Depth;
    }
}
