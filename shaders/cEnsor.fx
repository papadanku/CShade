
#include "shared/cShade.fxh"
#include "shared/cColor.fxh"

namespace cEnsor
{
    uniform int _Blockiness <
        ui_label = "Blockiness";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 7;
    > = 3;

    uniform float _Threshold <
        ui_label = "Search Threshold";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.1;

    uniform int _Select <
        ui_label = "Search Feature";
        ui_type = "combo";
        ui_items = "HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
    > = 2;

    uniform int _Comparison <
        ui_label = "Search Operator";
        ui_type = "combo";
        ui_items = "Less Than\0Greater Than\0Equal\0Not Equal\0Less Than of Equal\0Greater Than or Equal\0";
    > = 1;

    uniform bool _DisplayMask <
        ui_label = "Display Mask";
        ui_type = "radio";
    > = false;

    CREATE_TEXTURE_POOLED(TempTex0_RGBA8, BUFFER_SIZE_0, RGBA8, 8)
    CREATE_SRGB_SAMPLER(SampleTempTex0, TempTex0_RGBA8, POINT, MIRROR)

    float4 PS_Blit(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        return float4(tex2D(CShade_SampleColorTex, Input.Tex0).rgb, 1.0);
    }

    float4 PS_Censor(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
        float4 Pixel = tex2Dlod(SampleTempTex0, float4(Input.Tex0, 0.0, _Blockiness));

        // Initialize variables
        float Feature = 0.0;
        bool Mask = false;

        switch(_Select)
        {
            case 0:
                Feature = CColor_GetHSVfromRGB(Pixel.rgb).r;
                break;
            case 1:
                Feature = CColor_GetHSVfromRGB(Pixel.rgb).g;
                break;
            case 2:
                Feature = CColor_GetHSVfromRGB(Pixel.rgb).b;
                break;
            case 3:
                Feature = CColor_GetHSLfromRGB(Pixel.rgb).r;
                break;
            case 4:
                Feature = CColor_GetHSLfromRGB(Pixel.rgb).g;
                break;
            case 5:
                Feature = CColor_GetHSLfromRGB(Pixel.rgb).b;
                break;
            case 6:
                Feature = CColor_GetHSIfromRGB(Pixel.rgb).r;
                break;
            case 7:
                Feature = CColor_GetHSIfromRGB(Pixel.rgb).g;
                break;
            case 8:
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

        if(_DisplayMask)
        {
            return Mask;
        }
        else
        {
            return lerp(Color, Pixel, Mask);
        }
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
            VertexShader = CShade_VS_Quad;
            PixelShader = PS_Censor;
        }
    }
}
