#define CSHADE_THRESHOLD

#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform float _Threshold <
    ui_category = "Main Shader";
    ui_label = "Luminance Level Threshold";
    ui_min = 0.0;
    ui_type = "drag";
    ui_tooltip = "Sets the luminance level above which pixels will be affected by the threshold effect.";
> = 0.8;

uniform float _Smooth <
    ui_category = "Main Shader";
    ui_label = "Threshold Transition Smoothness";
    ui_min = 0.0;
    ui_type = "drag";
    ui_tooltip = "Controls the smoothness of the transition between areas above and below the threshold.";
> = 0.5;

uniform float _Intensity <
    ui_category = "Main Shader";
    ui_label = "Effect Strength";
    ui_min = 0.0;
    ui_type = "drag";
    ui_tooltip = "Controls the overall intensity or strength of the threshold effect.";
> = 1.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0);

    // Under-threshold
    float Brightness = CColor_RGBtoLuma(Color.rgb, 3);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);

    Output = CBlend_OutputChannels(saturate(Color.rgb * _Intensity), _CShade_AlphaFactor);
}

technique CShade_Threshold
<
    ui_label = "CShade / Threshold";
    ui_tooltip = "Threshold the image.";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
