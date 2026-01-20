#define CSHADE_CHROMATICITY

/*
    This shader visualizes various color spaces, focusing on the luminance and chromaticity representations of an image. It offers multiple display modes, allowing users to view chrominance, luminance, or a split view of both. The shader provides numerous algorithms for calculating grayscale luminance and chromaticity, including options like HSV, HSL, HSI, YCoCg, OKLab, and OKLch. This effect primarily serves as a diagnostic and analytical tool for understanding color data.
*/

#include "shared/cColor.fxh"

/* Shader Options */

uniform int _DisplayMode <
    ui_items = "Chrominance | Luminance\0Luminance | Chrominance\0Chrominance Only\0Luminance Only\0";
    ui_label = "Displayed Space";
    ui_type = "combo";
    ui_tooltip = "Selects the output mode: either the chrominance or luminance planes.";
> = 0;

uniform float _SplitBias <
    ui_label = "Split Bias";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_tooltip = "Adjusts the split bias for certain display modes.";
> = 0.5;

uniform int _GraySpace <
    ui_items = "Average\0Min\0Median\0Max\0Length\0Min+Max\0None\0";
    ui_label = "Luminance Space";
    ui_type = "combo";
    ui_tooltip = "Chooses the method used to convert the color image to grayscale, based on different luminance calculation techniques.";
> = 0;

uniform int _ChromaSpace <
    ui_items = "Length / XY\0Length / XYZ\0Average / XY\0Average / XYZ\0Sum / XY\0Sum / XYZ\0Max / XY\0Max / XYZ\0Ratio / XY\0Spherical / XY\0Hue-Saturation / HSI\0Hue-Saturation / HSL\0Hue-Saturation / HSV\0YCoCg / XY\0OKLab / AB\0OKLch / CH\0";
    ui_label = "Chromaticity Space";
    ui_type = "combo";
    ui_tooltip = "Chooses the method for calculating and displaying chromaticity, which represents the color's purity and hue independent of brightness.";
> = 0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/* Pixel Shaders */

float3 DiplayChromaSpace(float4 Color, float4 Gamma)
{
    float3 Output = float3(0.0, 0.0, 0.0);

    switch(_ChromaSpace)
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

    return Output;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float4 Gamma = tex2D(CShade_SampleGammaTex, Input.Tex0);

    // Initialize
    Output = float4(0.0, 0.0, 0.0, 1.0);

    // Precalculate this to avoid branching overload in lower-optimization levels
    float3 Chroma = DiplayChromaSpace(Color, Gamma);
    float3 Luma = CColor_RGBtoLuma(Color.rgb, _GraySpace);

    switch (_DisplayMode)
    {
        case 0:
            Output.rgb = lerp(Chroma, Luma, Input.Tex0.x >= _SplitBias);
            break;
        case 1:
            Output.rgb = lerp(Luma, Chroma, Input.Tex0.x >= _SplitBias);
            break;
        case 2:
            Output.rgb = Chroma;
            break;
        case 3:
            Output.rgb = Luma;
            break;
    }

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Output.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Output.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_Chromaticity
<
    ui_label = "CShade | Display Color Spaces";
    ui_tooltip = "Effect displays various grayscale or chromaticity spaces.";
>
{
    pass ColorSpace
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
