
#include "cGaussianBlur.fxh"

technique CShade_HorizontalBlur
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_HGaussianBlur;
    }
}
