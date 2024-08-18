
/*
    [Shader Options]
*/

uniform int _Select <
    ui_label = "Luminance Method";
    ui_type = "combo";
    ui_items = "Average\0Min\0Median\0Max\0Length\0Min+Max\0None\0";
> = 0;

#include "shared/cShade.fxh"
#include "shared/cColor.fxh"
#include "shared/cBlendOp.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Luminance(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float3 Luma = CColor_GetLuma(Color.rgb, _Select);
    return float4(Luma, _CShadeAlphaFactor);
}

technique CShade_Grayscale
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLENDOP_OUTPUT_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Luminance;
    }
}
