
#include "cGaussianBlur.fxh"

technique CShade_VerticalBlur
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_VGaussianBlur;
    }
}
