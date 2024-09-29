#define CSHADE_THRESHOLD

#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform float _Threshold <
    ui_label = "Threshold";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.8;

uniform float _Smooth <
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.5;

uniform float _Intensity <
    ui_label = "Intensity";
    ui_type = "drag";
    ui_min = 0.0;
> = 1.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Threshold(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = CShade_BackBuffer2D(Input.Tex0);

    // Under-threshold
    float Brightness = CColor_GetLuma(Color.rgb, 3);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);
    return CBlend_OutputChannels(float4(saturate(Color.rgb * _Intensity), _CShadeAlphaFactor));
}

technique CShade_Threshold < ui_tooltip = "Threshold the image (use \"Preprocessor Definitions\" for blending)"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Threshold;
    }
}
