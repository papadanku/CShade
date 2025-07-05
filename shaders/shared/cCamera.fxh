
#if !defined(INCLUDE_CCAMERA_OUTPUT)
    #define INCLUDE_CCAMERA_OUTPUT

    uniform float _CShadeExposureSmoothingSpeed <
        ui_category = "Pipeline · Output · Auto Exposure";
        ui_label = "Smoothing Speed";
        ui_type = "slider";
        ui_min = 0.1;
        ui_max = 1.0;
    > = 0.25;

    uniform float _CShadeExposureBias <
        ui_category = "Pipeline · Output · Auto Exposure";
        ui_label = "Compensation Bias";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = -4.0;
        ui_max = 4.0;
    > = 1.0;

    uniform float _CShadeExposureRange <
        ui_category = "Pipeline · Output · Auto Exposure";
        ui_label = "Compensation Range";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = 1.0;
        ui_max = 4.0;
    > = 1.0;

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html
    float CCamera_GetLogLuminance(float3 Color)
    {
        float Luminance = max(max(Color.r, Color.g), Color.b);
        return log(max(Luminance, 1e-2));
    }

    float4 CCamera_CreateExposureTex(float Luminance, float FrameTime)
    {
        // .rgb = Output the highest brightness out of red/green/blue component
        // .a = Output the weight for Temporal Blending Weight
        float Delay = 1e-3 * FrameTime;
        return float4((float3)Luminance, saturate(Delay * _CShadeExposureSmoothingSpeed));
    }

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

    void CCamera_ApplyAverageLumaOverlay(inout float3 Color, in float2 UnormTex, in Exposure E, in float2 ExposureOffset)
    {
        // Maps texture coordinates less-than/equal to the brightness.
        // We use [-1,-1] texture coordinates and bias them by 0.5 to have 0.0 be at the middle-left of the screen.
        UnormTex /= _AverageExposureScale;
        UnormTex += float2(-ExposureOffset.x, ExposureOffset.y);

        float AETex = UnormTex.x + 0.5;
        float3 AEMask = lerp(Color * 0.1, 1.0, AETex <= E.ExpLuma);

        // Mask between auto exposure bar color
        float2 CropTex = UnormTex + float2(0.0, -0.5);
        float2 Crop = step(abs(CropTex), float2(0.5, 0.01));
        float CropMask = Crop.x * Crop.y;

        // Composite
        Color = lerp(Color, AEMask, CropMask);
    }

#endif
