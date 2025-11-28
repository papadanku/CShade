#define CSHADE_SOLIDCOLOR

/*
    [Shader Options]
*/

uniform bool _BlendWithAlpha <
    ui_category = "Main Shader";
    ui_label = "Blend with Texture Alpha";
    ui_type = "radio";
    ui_tooltip = "When enabled, the output color will be blended with the computed alpha channel from the texture.";
> = false;

uniform float4 _Color <
    ui_category = "Main Shader";
    ui_label = "Solid Color";
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Sets the solid color that the shader will output.";
> = 0.5;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    #if (CBLEND_BLENDENABLE == TRUE)
        float Alpha = _BlendWithAlpha ? _Color.a * _CShade_AlphaFactor : _CShade_AlphaFactor;
    #else
        float Alpha = _Color.a;
    #endif

    Output = CBlend_OutputChannels(_Color.rgb, Alpha);
}

technique CShade_SolidColor
<
    ui_label = "CShade / Solid Color";
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
