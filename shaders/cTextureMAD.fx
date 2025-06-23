#define CSHADE_TEXTUREMAD

/*
    [Shader Options]
*/

uniform int _Order <
    ui_label = "Order of Operations";
    ui_type = "combo";
    ui_items = "Multiply & Add\0Add & Multiply\0";
> = 0;

uniform float3 _Multiply <
    ui_label = "Multiplication";
    ui_type = "slider";
    ui_min = -2.0;
    ui_max = 2.0;
> = 1.0;

uniform float3 _Addition <
    ui_label = "Addition";
    ui_type = "slider";
    ui_min = -2.0;
    ui_max = 2.0;
> = 0.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_TextureMAD(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Texture = CShadeHDR_Tex2Dlod_InvTonemap(CShade_SampleColorTex, float4(Input.Tex0, 0.0, 0.0));

    switch (_Order)
    {
        case 0:
            Texture.rgb *= _Multiply;
            Texture.rgb += _Addition;
            break;
        case 1:
            Texture.rgb += _Addition;
            Texture.rgb *= _Multiply;
            break;
    }

    return CBlend_OutputChannels(float4(Texture.rgb, _CShadeAlphaFactor));
}

technique CShade_SolidColor
<
    ui_label = "CShade · Multiply & Add";
    ui_tooltip = "Applies a multiply and add to the color (use \"Preprocessor Definitions\" for blending).";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_TextureMAD;
    }
}
