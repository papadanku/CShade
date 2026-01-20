#define CSHADE_THRESHOLD

/*
    This shader applies a threshold effect to the image, isolating and emphasizing areas based on their luminance. Users can define a luminance level threshold to control which pixels are affected. The shader also provides a smoothness parameter to soften the transition between affected and unaffected areas, and an intensity control for the overall strength of the effect. This can be used for effects such as bloom extraction, posterization, or creating high-contrast visuals.
*/

#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/* Shader Options */

uniform float _Threshold <
    ui_label = "Luminance Level Threshold";
    ui_min = 0.0;
    ui_type = "drag";
    ui_tooltip = "Sets the luminance level above which pixels will be affected by the threshold effect.";
> = 0.8;

uniform float _Smooth <
    ui_label = "Threshold Transition Smoothness";
    ui_min = 0.0;
    ui_type = "drag";
    ui_tooltip = "Controls the smoothness of the transition between areas above and below the threshold.";
> = 0.5;

uniform float _Intensity <
    ui_label = "Effect Strength";
    ui_min = 0.0;
    ui_type = "drag";
    ui_tooltip = "Controls the overall intensity or strength of the threshold effect.";
> = 1.0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/* Pixel Shaders */

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);

    // Under-threshold
    float Brightness = CColor_RGBtoLuma(Color.rgb, 3);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Color.rgb = saturate(Color.rgb * _Intensity);

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Color.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Color.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_Threshold
<
    ui_label = "CShade | Threshold";
    ui_tooltip = "Threshold the image.";
>
{
    pass Threshold
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
