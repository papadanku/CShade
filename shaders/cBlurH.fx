#define CSHADE_HORIZONTALBLUR

/*
    This shader applies a horizontal Gaussian blur to the image. It smoothes the image along the horizontal axis, reducing sharp details and creating a softening effect.
*/

#include "cBlur.fxh"

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output.rgb = GetGaussianBlur(Input.Tex0, true).rgb;
    Output = CBlend_OutputChannels(Output.rgb, _CShade_AlphaFactor);
}

technique CShade_HorizontalBlur
<
    ui_label = "CShade / Horizontal Blur";
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
