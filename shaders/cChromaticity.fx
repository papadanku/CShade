#define CSHADE_CHROMATICITY

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_label = "Chromaticity Method";
    ui_type = "combo";
    ui_items = "Length (XY)\0Length (XYZ)\0Average (XY)\0Average (XYZ)\0Sum (XY)\0Sum (XYZ)\0Max (XY)\0Max (XYZ)\0Ratio (XY)\0Spherical (XY)\0Hue-Saturation (HSI)\0Hue-Saturation (HSL)\0Hue-Saturation (HSV)\0YCoCg (XY)\0OKLab (AB)\0OKLch (CH)\0";
> = 0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Chromaticity(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = CShade_BackBuffer2D(Input.Tex0).rgb;
    float3 Gamma = tex2D(CShade_SampleGammaTex, Input.Tex0).rgb;
    float4 Chromaticity = 0.0;

    switch(_Select)
    {
        case 0: // Length (XY)
            Chromaticity.rg = CColor_GetSumChromaticity(Color, 0).rg;
            break;
        case 1: // Length (XYZ)
            Chromaticity.rgb = CColor_GetSumChromaticity(Color, 0).rgb;
            break;
        case 2: // Average (XY)
            Chromaticity.rg = CColor_GetSumChromaticity(Color, 1).rg;
            break;
        case 3: // Average (XYZ)
            Chromaticity.rgb = CColor_GetSumChromaticity(Color, 1).rgb;
            break;
        case 4: // Sum (XY)
            Chromaticity.rg = CColor_GetSumChromaticity(Color, 2).rg;
            break;
        case 5: // Sum (XYZ)
            Chromaticity.rgb = CColor_GetSumChromaticity(Color, 2).rgb;
            break;
        case 6: // Max (XY)
            Chromaticity.rg = CColor_GetSumChromaticity(Color, 3).rg;
            break;
        case 7: // Max (XYZ)
            Chromaticity.rgb = CColor_GetSumChromaticity(Color, 3).rgb;
            break;
        case 8: // Ratio (XY)
            Chromaticity.rg = CColor_GetRatioRG(Color);
            break;
        case 9: // Spherical (XY)
            Chromaticity.rg = CColor_GetSphericalRG(Color);
            break;
        case 10: // Hue-Saturation (HSI)
            Chromaticity.rg = CColor_GetHSIfromRGB(Color).rg;
            break;
        case 11: // Hue-Saturation (HSL)
            Chromaticity.rg = CColor_GetHSLfromRGB(Color).rg;
            break;
        case 12: // Hue-Saturation (HSV)
            Chromaticity.rg = CColor_GetHSVfromRGB(Color).rg;
            break;
        case 13: // CoCg (XY)
            Chromaticity.rg = CColor_GetYCOCGfromRGB(Gamma, true).yz;
            break;
        case 14: // OKLab (AB)
            Chromaticity.rg = CColor_GetOKLABfromRGB(Color).yz;
            Chromaticity.rg = (Chromaticity.rg + 0.4) / 0.8;
            break;
        case 15: // OKLch (CH)
            const float Pi2 = CMath_GetPi() * 2.0;
            Chromaticity.rg = CColor_GetOKLCHfromRGB(Color).yz;
            Chromaticity.r /= length(float2(0.4, 0.4));
            Chromaticity.g /= Pi2;
            break;
        default: // No Chromaticity
            Chromaticity.rgb = 0.0;
            break;
    }

    return CBlend_OutputChannels(float4(Chromaticity.rgb, _CShadeAlphaFactor));
}

technique CShade_Chromaticity < ui_tooltip = "Adjustable chromaticity effect"; >
{
    pass
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Chromaticity;
    }
}
