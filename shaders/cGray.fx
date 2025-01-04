#define CSHADE_GRAYSCALE

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_label = "Luminance Method";
    ui_type = "combo";
    ui_items = "Average\0Min\0Median\0Max\0Length\0Min+Max\0None\0";
> = 0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Luminance(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = CShade_BackBuffer2D(Input.Tex0);
    float3 Luma = CColor_GetLuma(Color.rgb, _Select);
    return CBlend_OutputChannels(float4(Luma, _CShadeAlphaFactor));
}

technique CShade_Grayscale < ui_tooltip = "Adjustable grayscale effect"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Luminance;
    }
}
