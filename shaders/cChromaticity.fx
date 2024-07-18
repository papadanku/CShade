
#include "shared/cGraphics.fxh"
#include "shared/cColorSpaces.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_label = "Chromaticity Method";
    ui_type = "combo";
    ui_items = "Length (XY)\0Length (XYZ)\0Average (XY)\0Average (XYZ)\0Sum (XY)\0Sum (XYZ)\0Max (XY)\0Max (XYZ)\0Ratio (XY)\0Spherical (XY)\0Hue-Saturation (HSI)\0Hue-Saturation (HSL)\0Hue-Saturation (HSV)\0CoCg (XY)\0CrCb (XY)\0";
> = 0;

/*
    [Pixel Shaders]
*/

float4 PS_Chromaticity(VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 Gamma = tex2D(CShade_SampleGammaTex, Input.Tex0).rgb;
    float3 Chromaticity = 0.0;

    switch(_Select)
    {
        case 0: // Length (XY)
            Chromaticity.rg = CColorSpaces_GetSumChromaticity(Color, 0).rg;
            break;
        case 1: // Length (XYZ)
            Chromaticity.rgb = CColorSpaces_GetSumChromaticity(Color, 0).rgb;
            break;
        case 2: // Average (XY)
            Chromaticity.rg = CColorSpaces_GetSumChromaticity(Color, 1).rg;
            break;
        case 3: // Average (XYZ)
            Chromaticity.rgb = CColorSpaces_GetSumChromaticity(Color, 1).rgb;
            break;
        case 4: // Sum (XY)
            Chromaticity.rg = CColorSpaces_GetSumChromaticity(Color, 2).rg;
            break;
        case 5: // Sum (XYZ)
            Chromaticity.rgb = CColorSpaces_GetSumChromaticity(Color, 2).rgb;
            break;
        case 6: // Max (XY)
            Chromaticity.rg = CColorSpaces_GetSumChromaticity(Color, 3).rg;
            break;
        case 7: // Max (XYZ)
            Chromaticity.rgb = CColorSpaces_GetSumChromaticity(Color, 3).rgb;
            break;
        case 8: // Ratio (XY)
            Chromaticity.rg = CColorSpaces_GetRatioRG(Color);
            break;
        case 9: // Spherical (XY)
            Chromaticity.rg = CColorSpaces_GetSphericalRG(Color);
            break;
        case 10: // Hue-Saturation (HSI)
            Chromaticity.rg = CColorSpaces_GetHSIfromRGB(Color).rg;
            break;
        case 11: // Hue-Saturation (HSL)
            Chromaticity.rg = CColorSpaces_GetHSLfromRGB(Color).rg;
            break;
        case 12: // Hue-Saturation (HSV)
            Chromaticity.rg = CColorSpaces_GetHSVfromRGB(Color).rg;
            break;
        case 13: // CoCg (XY)
            Chromaticity.rg = CColorSpaces_GetCoCg(Gamma);
            break;
        case 14: // CrCb (XY)
            Chromaticity.rg = CColorSpaces_GetCrCb(Gamma);
            break;
        default: // No Chromaticity
            Chromaticity.rgb = 0.0;
            break;
    }

    return float4(Chromaticity, 1.0);
}

technique CShade_Chromaticity
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Chromaticity;
    }
}
