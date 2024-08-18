
uniform float3 _Color <
    ui_label = "Color";
    ui_type = "color";
    ui_min = 0.0;
> = 1.0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Color(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CBlend_OutputChannels(float4(_Color, _CShadeAlphaFactor));
}

// Use BlendOp to multiple the backbuffer with this quad's color
technique CShade_SolidColor
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Color;
    }
}
