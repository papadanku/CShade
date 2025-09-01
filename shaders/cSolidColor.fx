#define CSHADE_SOLIDCOLOR

/*
    [Shader Options]
*/

uniform float4 _Color <
    ui_label = "Color";
    ui_type = "color";
    ui_min = 0.0;
> = 0.5;

#include "shared/cShade.fxh"

uniform bool _BlendWithAlpha <
    ui_category = "Pipeline · Output · Blending";
    ui_label = "Apply Texture Alpha";
    ui_tooltip = "If the user enabled CBLEND_BLENDENABLE, blend with the computed alpha channel.";
    ui_type = "radio";
> = false;

#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    #if (CBLEND_BLENDENABLE == TRUE)
        float Alpha = _BlendWithAlpha ? _Color.a * _CShadeAlphaFactor : _CShadeAlphaFactor;
    #else
        float Alpha = _Color.a;
    #endif

    Output = CBlend_OutputChannels(_Color.rgb, Alpha);
}

technique CShade_SolidColor
<
    ui_label = "CShade · Solid Color";
    ui_tooltip = "Output a solid color.";
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
