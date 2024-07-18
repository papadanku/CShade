
#if !defined(INCLUDE_CAMERA)
    #define INCLUDE_CAMERA

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html

    float GetLogLuminance(float3 Color)
    {
        float Luminance = max(max(Color.r, Color.g), Color.b);
        return log(max(Luminance, 1e-2));
    }

    #if defined(INCLUDE_CCAMERA_INPUT)
        uniform float _CShadeExposureSmoothingSpeed <
            ui_category = "Output: AutoExposure";
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

    #if defined(INCLUDE_CCAMERA_OUTPUT)
        uniform float _CShadeExposureBias <
            ui_category = "Output: AutoExposure";
            ui_label = "Exposure Compensation Bias";
            ui_type = "slider";
            ui_step = 0.001;
            ui_min = -4.0;
            ui_max = 4.0;
        > = 1.0;

        uniform float _CShadeExposureRange <
            ui_category = "Output: AutoExposure";
            ui_label = "Exposure Compensation Range";
            ui_type = "slider";
            ui_step = 0.001;
            ui_min = 1.0;
            ui_max = 4.0;
        > = 1.0;

        struct Exposure
        {
            float ExpLuma;
            float Ev100;
            float Value;
        };

        Exposure CCamera_GetExposureData(float LumaTex)
        {
            Exposure Output;
            Output.ExpLuma = exp(LumaTex);
            Output.Ev100 = log2(Output.ExpLuma * 100.0 / 12.5);
            Output.Ev100 -= _CShadeExposureBias; // optional manual bias
            Output.Ev100 = clamp(Output.Ev100, -_CShadeExposureRange, _CShadeExposureRange);
            Output.Value = 1.0 / (1.2 * exp2(Output.Ev100));
            return Output;
        }

        float3 CCamera_ApplyAutoExposure(float3 Color, Exposure Input)
        {
            return Color * Input.Value;
        }
    #endif

#endif