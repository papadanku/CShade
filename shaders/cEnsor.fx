
#include "shared/cGraphics.fxh"
#include "shared/cBuffers.fxh"
#include "shared/cColorSpaces.fxh"

namespace cEnsor
{
    uniform int _Select <
        ui_label = "Feature Search Method";
        ui_type = "combo";
        ui_items = "HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
    > = 2;

    uniform int _Blockiness <
        ui_label = "Blockiness";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 7;
    > = 3;

    uniform float _Threshold <
        ui_label = "Value Threshold";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.1;

    uniform bool _DisplayMask <
        ui_label = "Display Mask";
        ui_type = "radio";
    > = false;

    CREATE_SAMPLER(SampleTempTex0, TempTex0_RGB10A2, POINT, CLAMP)

    float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
    {
        return float4(tex2D(CShade_SampleColorTex, Input.Tex0).rgb, 1.0);
    }

    float4 PS_Censor(VS2PS_Quad Input) : SV_TARGET0
    {
        float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
        float4 Pixel = tex2Dlod(SampleTempTex0, float4(Input.Tex0, 0.0, _Blockiness));

        // Initialize feature
        float Feature = 0.0;

        switch(_Select)
        {
            case 0:
                Feature = GetHSVfromRGB(Pixel.rgb).r;
                break;
            case 1:
                Feature = GetHSVfromRGB(Pixel.rgb).g;
                break;
            case 2:
                Feature = GetHSVfromRGB(Pixel.rgb).b;
                break;
            case 3:
                Feature = GetHSLfromRGB(Pixel.rgb).r;
                break;
            case 4:
                Feature = GetHSLfromRGB(Pixel.rgb).g;
                break;
            case 5:
                Feature = GetHSLfromRGB(Pixel.rgb).b;
                break;
            case 6:
                Feature = GetHSIfromRGB(Pixel.rgb).r;
                break;
            case 7:
                Feature = GetHSIfromRGB(Pixel.rgb).g;
                break;
            case 8:
                Feature = GetHSIfromRGB(Pixel.rgb).b;
                break;
            default:
                Feature = 0.0;
                break;
        }

        bool Mask = saturate(Feature > _Threshold);

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
            VertexShader = VS_Quad;
            PixelShader = PS_Blit;
            RenderTarget = TempTex0_RGB10A2;
        }

        pass
        {
            SRGBWriteEnable = WRITE_SRGB;
            VertexShader = VS_Quad;
            PixelShader = PS_Censor;
        }
    }
}
