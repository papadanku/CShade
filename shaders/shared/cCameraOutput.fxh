
#include "cCamera.fxh"

#if !defined(INCLUDE_CCAMERA_OUTPUT)
    #define INCLUDE_CCAMERA_OUTPUT

    uniform float _CShadeExposureBias <
        ui_category = "[ Pipeline | Output | AutoExposure ]";
        ui_label = "Compensation Bias";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = -4.0;
        ui_max = 4.0;
    > = 1.0;

    uniform float _CShadeExposureRange <
        ui_category = "[ Pipeline | Output | AutoExposure ]";
        ui_label = "Compensation Range";
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
