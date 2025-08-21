#define CSHADE_SOLIDCOLOR

/*
    [Shader Options]
*/

uniform float4 _Color <
    ui_label = "Color";
    ui_type = "color";
    ui_min = 0.0;
> = 1.0;

#include "shared/cShade.fxh"

uniform bool _BlendWithAlpha <
    ui_category = "Pipeline · Output · Blending";
    ui_label = "Blend With Alpha Channel";
    ui_tooltip = "If the user enabled CBLEND_BLENDENABLE, blend with the computed alpha channel.";
    ui_type = "radio";
> = false;

#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Color(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    #if CBLEND_BLENDENABLE
        float Alpha = _BlendWithAlpha ? _Color.a * _CShadeAlphaFactor : _CShadeAlphaFactor;
    #else
        float Alpha = _Color.a;
    #endif

    return CBlend_OutputChannels(float4(_Color.rgb, Alpha));
}

technique CShade_SolidColor
<
    ui_label = "CShade · Solid Color";
    ui_tooltip = "Output a solid color (use \"Preprocessor Definitions\" for blending).";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Color;
    }
}
