#define CSHADE_VERTICALBLUR

/*
    This shader applies a vertical Gaussian blur to the image. It smoothes the image along the vertical axis, reducing sharp details and creating a softening effect.
*/

#include "cBlur.fxh"

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output.rgb = GetGaussianBlur(Input.Tex0, false).rgb;
    Output = CBlend_OutputChannels(Output.rgb, _CShade_AlphaFactor);
}

technique CShade_VerticalBlur
<
    ui_label = "CShade / Vertical Blur";
    ui_tooltip = "Horizonal Gaussian blur effect.";
>
{
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
