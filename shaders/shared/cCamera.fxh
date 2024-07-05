
#if !defined(INCLUDE_CAMERA)
    #define INCLUDE_CAMERA

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html

    uniform float _CShadeExposureBias <
        ui_category = "Output: AutoExposure";
        ui_label = "Exposure bias";
        ui_tooltip = "Optional manual bias ";
        ui_type = "drag";
        ui_step = 0.001;
        ui_min = 0.0;
        ui_max = 10.0;
    > = 0.0;

    uniform float _CShadeExposureSmoothingSpeed <
        ui_category = "Output: AutoExposure";
        ui_label = "Smoothing";
        ui_type = "slider";
        ui_tooltip = "Exposure smoothing speed";
        ui_min = 0.001;
        ui_max = 1.0;
    > = 0.5;

    float4 CreateExposureTex(float3 Color, float FrameTime)
    {
        float3 Luma = max(Color.r, max(Color.g, Color.b));

        // .rgb = Output the highest brightness out of red/green/blue component
        // .a = Output the weight for temporal blending
        float Delay = 1e-3 * FrameTime;
        return float4(log(max(Luma, 1e-2)), saturate(Delay * _CShadeExposureSmoothingSpeed));
    }

    float3 ApplyAutoExposure(float3 Color, float Luma)
    {
        float LumaAverage = exp(Luma);
        float Ev100 = log2(LumaAverage * 100.0 / 12.5);
        Ev100 -= _CShadeExposureBias; // optional manual bias
        float Exposure = 1.0 / (1.2 * exp2(Ev100));
        return Color * Exposure;
    }

#endif