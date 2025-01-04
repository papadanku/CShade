#define CSHADE_VERTICALBLUR

#include "cBlur.fxh"

technique CShade_VerticalBlur < ui_tooltip = "Horizonal Gaussian blur effect"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_VGaussianBlur;
    }
}
