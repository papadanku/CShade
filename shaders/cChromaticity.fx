#define CSHADE_CHROMATICITY

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_category = "Main Shader";
    ui_label = "Chromaticity Method";
    ui_tooltip = "Chooses the method for calculating and displaying chromaticity, which represents the color's purity and hue independent of brightness.";
    ui_type = "combo";
    ui_items = "Length / XY\0Length / XYZ\0Average / XY\0Average / XYZ\0Sum / XY\0Sum / XYZ\0Max / XY\0Max / XYZ\0Ratio / XY\0Spherical / XY\0Hue-Saturation / HSI\0Hue-Saturation / HSL\0Hue-Saturation / HSV\0YCoCg / XY\0OKLab / AB\0OKLch / CH\0";
> = 0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 Gamma = tex2D(CShade_SampleGammaTex, Input.Tex0).rgb;

    // Initialize
    Output = float4(0.0, 0.0, 0.0, 1.0);

    switch(_Select)
    {
        case 0: // Length (XY)
            Output.rg = CColor_RGBtoChromaticityRGB(Color, 0).rg;
            break;
        case 1: // Length (XYZ)
            Output.rgb = CColor_RGBtoChromaticityRGB(Color, 0).rgb;
            break;
        case 2: // Average (XY)
            Output.rg = CColor_RGBtoChromaticityRGB(Color, 1).rg;
            break;
        case 3: // Average (XYZ)
            Output.rgb = CColor_RGBtoChromaticityRGB(Color, 1).rgb;
            break;
        case 4: // Sum (XY)
            Output.rg = CColor_RGBtoChromaticityRGB(Color, 2).rg;
            break;
        case 5: // Sum (XYZ)
            Output.rgb = CColor_RGBtoChromaticityRGB(Color, 2).rgb;
            break;
        case 6: // Max (XY)
            Output.rg = CColor_RGBtoChromaticityRGB(Color, 3).rg;
            break;
        case 7: // Max (XYZ)
            Output.rgb = CColor_RGBtoChromaticityRGB(Color, 3).rgb;
            break;
        case 8: // Ratio (XY)
            Output.rg = CColor_RGBtoChromaticityRG(Color);
            break;
        case 9: // Spherical (XY)
            Output.rg = CColor_RGBtoSphericalRGB(Color).yz;
            break;
        case 10: // Hue-Saturation (HSI)
            Output.rg = CColor_RGBtoHSI(Color).rg;
            break;
        case 11: // Hue-Saturation (HSL)
            Output.rg = CColor_RGBtoHSL(Color).rg;
            break;
        case 12: // Hue-Saturation (HSV)
            Output.rg = CColor_RGBtoHSV(Color).rg;
            break;
        case 13: // CoCg (XY)
            Output.rg = CColor_SRGBtoYCOCGR(Gamma, true).yz;
            break;
        case 14: // OKLab (AB)
            Output.rg = CColor_RGBtoOKLAB(Color).yz;
            Output.rg = (Output.rg + 0.4) / 0.8;
            break;
        case 15: // OKLch (CH)
            const float Pi2 = 1.0 / CMath_GetPi();
            Output.rg = CColor_RGBtoOKLCH(Color).yz;
            Output.g *= Pi2;
            Output.g = CMath_SNORMtoUNORM_FLT1(Output.g);
            break;
        default: // No Output
            Output.rgb = 0.0;
            break;
    }

    Output = CBlend_OutputChannels(Output.rgb, _CShade_AlphaFactor);
}

technique CShade_Chromaticity
<
    ui_label = "CShade · Chromaticity";
    ui_tooltip = "Adjustable chromaticity effect.";
>
{
    pass
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
