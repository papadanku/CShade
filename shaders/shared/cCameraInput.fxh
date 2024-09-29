
#include "cCamera.fxh"

#if !defined(INCLUDE_CCAMERA_INPUT)
    #define INCLUDE_CCAMERA_INPUT

    uniform float _CShadeExposureSmoothingSpeed <
        ui_category = "[ Pipeline | Output | AutoExposure ]";
        ui_label = "Smoothing Speed";
        ui_type = "slider";
        ui_min = 0.1;
        ui_max = 1.0;
    > = 0.25;

    float4 CCamera_CreateExposureTex(float Luminance, float FrameTime)
    {
        // .rgb = Output the highest brightness out of red/green/blue component
        // .a = Output the weight for temporal blending
        float Delay = 1e-3 * FrameTime;
        return float4((float3)Luminance, saturate(Delay * _CShadeExposureSmoothingSpeed));
    }

#endif
