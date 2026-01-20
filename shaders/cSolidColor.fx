#define CSHADE_SOLIDCOLOR

/*
    This shader outputs a user-defined solid color across the entire screen. It provides controls for customizing the output color and includes an option to blend this solid color with the computed alpha channel from the texture. This shader is useful for creating simple overlays, background fills, or for debugging purposes.
*/

/* Shader Options */

uniform bool _BlendWithAlpha <
    ui_label = "Blend with Texture Alpha";
    ui_type = "radio";
    ui_tooltip = "When enabled, the output color will be blended with the computed alpha channel from the texture.";
> = false;

uniform float4 _Color <
    ui_label = "Solid Color";
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Sets the solid color that the shader will output.";
> = 0.5;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/* Pixel Shaders */

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // RENDER
    #if (CBLEND_BLENDENABLE == TRUE)
        float Alpha = _BlendWithAlpha ? _Color.a * _CShade_AlphaFactor : _CShade_AlphaFactor;
        Output = float4(_Color.rgb, Alpha);
    #else
        Output = _Color;
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_SolidColor
<
    ui_label = "CShade | Solid Color";
    ui_tooltip = "Output a solid color.";
>
{
    pass SolidColor
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
