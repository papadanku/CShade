#define CSHADE_VERTICALBLUR

/*
    This shader applies a vertical Gaussian blur to the image. It smoothes the image along the vertical axis, reducing sharp details and creating a softening effect.
*/

/* Shader Options */

uniform float _Sigma <
    ui_label = "Blur Strength";
    ui_max = 16.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the spread of the Gaussian blur. Higher values result in a wider and more intense blur.";
> = 1.0;

#include "shared/cBlur.fxh"
#include "cBlur.fxh"

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 BlurColor = GetGaussianBlur(Input.Tex0, _Sigma, false).rgb;

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(BlurColor, _CShade_AlphaFactor);
    #else
        Output = float4(BlurColor, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_VerticalBlur
<
    ui_label = "CShade | Vertical Blur";
    ui_tooltip = "Horizonal Gaussian blur effect.";
>
{
    pass VerticalBlur
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
