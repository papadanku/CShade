#define CSHADE_CENSOR

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _DisplayMode <
    ui_category = "Main Shader";
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Output\0Mask\0";
> = 0;

uniform int _DetectionMode <
    ui_category = "Main Shader";
    ui_label = "Search Algorithm";
    ui_type = "combo";
    ui_items = "Color\0\HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
> = 3;

uniform int _Comparison <
    ui_category = "Main Shader";
    ui_label = "Search Operator";
    ui_type = "combo";
    ui_items = "Less Than\0Greater Than\0Equal\0Not Equal\0Less Than or Equal\0Greater Than or Equal\0";
> = 1;

uniform float _Blockiness <
    ui_category = "Main Shader";
    ui_label = "Blockiness";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
    ui_step = 0.1;
> = 3.0;

uniform float _Threshold <
    ui_category = "Main Shader";
    ui_label = "Search Threshold";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.1;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

CREATE_TEXTURE_POOLED(TempTex0_RGBA8_8, BUFFER_SIZE_0, RGBA8, 8)

sampler2D SampleTempTex0
{
    Texture = TempTex0_RGBA8_8;
    MagFilter = POINT;
    MinFilter = POINT;
    MipFilter = LINEAR;
    AddressU = MIRROR;
    AddressV = MIRROR;
    AddressW = MIRROR;
    SRGBTexture = READ_SRGB;
};

float4 PS_Blit(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0);

    switch(_DetectionMode)
    {
        case 0:
            Color.a = 1.0;
            break;
        case 1:
            Color.a = CColor_RGBtoHSV(Color.rgb).r;
            break;
        case 2:
            Color.a = CColor_RGBtoHSV(Color.rgb).g;
            break;
        case 3:
            Color.a = CColor_RGBtoHSV(Color.rgb).b;
            break;
        case 4:
            Color.a = CColor_RGBtoHSL(Color.rgb).r;
            break;
        case 5:
            Color.a = CColor_RGBtoHSL(Color.rgb).g;
            break;
        case 6:
            Color.a = CColor_RGBtoHSL(Color.rgb).b;
            break;
        case 7:
            Color.a = CColor_RGBtoHSI(Color.rgb).r;
            break;
        case 8:
            Color.a = CColor_RGBtoHSI(Color.rgb).g;
            break;
        case 9:
            Color.a = CColor_RGBtoHSI(Color.rgb).b;
            break;
        default:
            Color.a = 1.0;
            break;
    }

    return Color;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0);
    float4 Blocks = tex2Dlod(SampleTempTex0, float4(Input.Tex0, 0.0, _Blockiness));

    // Initialize variables
    float3 Feature = (_DetectionMode == 0) ? Blocks.rgb : Blocks.aaa;
    bool3 Mask = false;

    switch (_Comparison)
    {
        case 0:
            Mask = Feature < _Threshold;
            break;
        case 1:
            Mask = Feature > _Threshold;
            break;
        case 2:
            Mask = Feature == _Threshold;
            break;
        case 3:
            Mask = Feature != _Threshold;
            break;
        case 4:
            Mask = Feature <= _Threshold;
            break;
        case 5:
            Mask = Feature >= _Threshold;
            break;
    }

    if (_DisplayMode == 1)
    {
        Output.rgb = Mask;
    }
    else
    {
        Output.rgb = lerp(Color.rgb, Blocks.rgb, Mask);
    }

    Output = CBlend_OutputChannels(Output.rgb, _CShade_AlphaFactor);
}

technique CShade_Censor
<
    ui_label = "CShade · Censor";
    ui_tooltip = "Pixelates the screen based on features.";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGBA8_8;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
