
uniform int _Blockiness <
    ui_label = "Blockiness";
    ui_type = "slider";
    ui_min = 0;
    ui_max = 7;
> = 3;

uniform int _DetectionMode <
    ui_label = "Search Mode";
    ui_type = "combo";
    ui_items = "Color\0\HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
> = 0;

uniform int _Comparison <
    ui_label = "Search Operator";
    ui_type = "combo";
    ui_items = "Less Than\0Greater Than\0Equal\0Not Equal\0Less Than or Equal\0Greater Than or Equal\0";
> = 1;

uniform float _Threshold <
    ui_label = "Search Threshold";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.1;

uniform int _DisplayMode <
    ui_label = "Display Mode";
    ui_type = "radio";
    ui_items = "Output\0Mask\0";
> = 0;

#include "shared/cColor.fxh"

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

CREATE_TEXTURE_POOLED(TempTex0_RGBA8, BUFFER_SIZE_0, RGBA8, 8)
CREATE_SRGB_SAMPLER(SampleTempTex0, TempTex0_RGBA8, POINT, MIRROR, MIRROR, MIRROR)

float4 PS_Blit(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(CShade_SampleColorTex, Input.Tex0).rgb, 1.0);
}

float4 PS_Censor(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float4 Pixel = tex2Dlod(SampleTempTex0, float4(Input.Tex0, 0.0, _Blockiness));

    // Initialize variables
    float4 Feature = 0.0;
    bool4 Mask = false;
    float4 OutputColor = 0.0;

    switch(_DetectionMode)
    {
        case 0:
            Feature = Pixel;
            break;
        case 1:
            Feature = CColor_GetHSVfromRGB(Pixel.rgb).r;
            break;
        case 2:
            Feature = CColor_GetHSVfromRGB(Pixel.rgb).g;
            break;
        case 3:
            Feature = CColor_GetHSVfromRGB(Pixel.rgb).b;
            break;
        case 4:
            Feature = CColor_GetHSLfromRGB(Pixel.rgb).r;
            break;
        case 5:
            Feature = CColor_GetHSLfromRGB(Pixel.rgb).g;
            break;
        case 6:
            Feature = CColor_GetHSLfromRGB(Pixel.rgb).b;
            break;
        case 7:
            Feature = CColor_GetHSIfromRGB(Pixel.rgb).r;
            break;
        case 8:
            Feature = CColor_GetHSIfromRGB(Pixel.rgb).g;
            break;
        case 9:
            Feature = CColor_GetHSIfromRGB(Pixel.rgb).b;
            break;
        default:
            Feature = 0.0;
            break;
    }

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
        OutputColor = Mask;
    }
    else
    {
        OutputColor = lerp(Color, Pixel, Mask);
    }

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_Censor
{
    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGBA8;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Censor;
    }
}
