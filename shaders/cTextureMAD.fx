#define CSHADE_TEXTUREMAD

/*
    [Shader Options]
*/

uniform int _Order <
    ui_label = "Order of Operations";
    ui_type = "combo";
    ui_items = "Multiply & Add\0Add & Multiply\0";
> = 0;

uniform float4 _Multiply <
    ui_label = "Multiplication";
    ui_type = "slider";
    ui_min = -2.0;
    ui_max = 2.0;
> = 1.0;

uniform float4 _Addition <
    ui_label = "Addition";
    ui_type = "slider";
    ui_min = -2.0;
    ui_max = 2.0;
> = 0.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

uniform bool _BlendWithAlpha <
    ui_category = "Pipeline · Output · Blending";
    ui_label = "Blend With Alpha Channel";
    ui_tooltip = "If the user enabled CBLEND_BLENDENABLE, blend with the computed alpha channel.";
    ui_type = "radio";
> = false;

/*
    [Pixel Shaders]
*/

float4 PS_TextureMAD(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Texture = CShadeHDR_Tex2Dlod_InvTonemap(CShade_SampleColorTex, float4(Input.Tex0, 0.0, 0.0));

    switch (_Order)
    {
        case 0:
            Texture *= _Multiply;
            Texture += _Addition;
            break;
        case 1:
            Texture += _Addition;
            Texture *= _Multiply;
            break;
    }

    #if CBLEND_BLENDENABLE
        float Alpha = _BlendWithAlpha ? Texture.a * _CShadeAlphaFactor : _CShadeAlphaFactor;
    #else
        float Alpha = Texture.a;
    #endif

    return CBlend_OutputChannels(float4(Texture.rgb, Alpha));
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
