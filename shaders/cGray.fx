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

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0);
    float3 Luma = CColor_RGBtoLuma(Color.rgb, _Select);

    Output = CBlend_OutputChannels(Luma, _CShadeAlphaFactor);
}

technique CShade_Grayscale
<
    ui_label = "CShade · Grayscale";
    ui_tooltip = "Adjustable grayscale effect.";
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
