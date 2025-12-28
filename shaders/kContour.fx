#define CSHADE_CONTOUR

/*
    This shader implements Keijiro Takahashi's KinoContour effect, which draws contour lines on the image by detecting edges based on gradients. It offers various edge detection methods (e.g., Sobel, Prewitt, Scharr) and allows weighting detection by color or luma. Users can adjust lower and upper thresholds for gradient magnitude, customize the color of contour lines and the background, and utilize multiple debug display modes to visualize gradients and magnitudes.
*/

/*
    MIT License

    Copyright (C) 2015-2017 Keijiro Takahashi

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

#ifndef SHADER_EDGE_DETECTION
    #define SHADER_EDGE_DETECTION 1
#endif

uniform int _DisplayMode <
    ui_category = "Main Shader";
    ui_items = "Output\0Debug · Quadrant\0Debug · Magnitude\0Debug · X Gradient\0Debug · Y Gradient\0";
    ui_label = "Display Mode";
    ui_type = "combo";
    ui_tooltip = "Controls how the contour effect is displayed, including various debug visualizations of gradients and magnitudes.";
> = 0;

uniform int _WeightMode <
    ui_category = "Main Shader";
    ui_items = "Color\0Luma\0";
    ui_label = "Edge Detection Method";
    ui_type = "combo";
    ui_tooltip = "Selects whether edge detection is based on color differences or luminance differences.";
> = 0;

uniform float _LowerThreshold <
    ui_category = "Main Shader";
    ui_label = "Lower Edge Threshold";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Sets the minimum gradient magnitude required for a pixel to be considered part of a contour.";
> = 0.05;

uniform float _UpperThreshold <
    ui_category = "Main Shader";
    ui_label = "Upper Edge Threshold";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Sets the maximum gradient magnitude for a pixel to be considered part of a contour, used in conjunction with the lower threshold.";
> = 0.5;

uniform float _ColorSensitivity <
    ui_category = "Main Shader";
    ui_label = "Color Difference Sensitivity";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls how sensitive the edge detection algorithm is to color differences when determining contours.";
> = 0.5;

uniform float4 _FrontColor <
    ui_category = "Main Shader";
    ui_label = "Contour Line Color";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Sets the color of the detected contour lines.";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _BackColor <
    ui_category = "Main Shader";
    ui_label = "Background Color";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Sets the background color that appears behind the contour lines.";
> = float4(0.0, 0.0, 0.0, 0.0);

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#include "shared/cEdge.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nEDGE_DETECTION_KERNEL - Edge Detection Kernel.\n\n\tOptions:\n\n\t\t0 (ddx, ddy)\n\t\t1 (Sobel Bilinear 3x3)\n\t\t2 (Prewitt Bilinear 5x5)\n\t\t3 (Sobel Bilinear 5x5)\n\t\t4 (Prewitt Bilinear 3x3)\n\t\t5 (Scharr Bilinear 3x3)\n\t\t6 (Frei-Chen)\n\n";
    ui_type = "radio";
> = 0;

/*
    [Pixel Shaders]
*/

float3 GetColorFromGradient(CEdge_Filter Input)
{
    return sqrt((Input.Gx.rgb * Input.Gx.rgb) + (Input.Gy.rgb * Input.Gy.rgb));
}

CEdge_Filter GetGradient(float2 Tex, float2 Delta)
{
    CEdge_Filter F;

    #if (SHADER_EDGE_DETECTION == 0) // ddx(), ddy()
        F = CEdge_GetDDXY(CShade_SampleColorTex, Tex);
    #elif (SHADER_EDGE_DETECTION == 1) // Bilinear 3x3 Sobel
        F = CEdge_GetBilinearSobel3x3(CShade_SampleColorTex, Tex, Delta);
    #elif (SHADER_EDGE_DETECTION == 2) // Bilinear 5x5 Prewitt
        F = CEdge_GetBilinearPrewitt5x5(CShade_SampleColorTex, Tex, Delta);
    #elif (SHADER_EDGE_DETECTION == 3) // Bilinear 5x5 Sobel by CeeJayDK
        F = CEdge_GetBilinearSobel5x5(CShade_SampleColorTex, Tex, Delta);
    #elif (SHADER_EDGE_DETECTION == 4) // 3x3 Prewitt
        F = CEdge_GetBilinearPrewitt3x3(CShade_SampleColorTex, Tex, Delta);
    #elif (SHADER_EDGE_DETECTION == 5) // 3x3 Scharr
        F = CEdge_GetBilinearScharr3x3(CShade_SampleColorTex, Tex, Delta);
    #else // Our default
        F = CEdge_GetBilinearSobel3x3(CShade_SampleColorTex, Tex, Delta);
    #endif

    return F;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float Threshold = _LowerThreshold;
    float InverseRange = 1.0 / (_UpperThreshold - _LowerThreshold);

    float2 Delta = fwidth(Input.Tex0);
    CMath_TexGrid Grid = CMath_GetTexGrid(Input.Tex0, 2);

    // If we are debugging, sampling in a quadrant.
    Input.Tex0 = (_DisplayMode == 1) ? Grid.Frac : Input.Tex0;

    // Get gradient information
    CEdge_Filter F = GetGradient(Input.Tex0, Delta);

    // Exception for non-directional methods such as Frei-Chen
    #if SHADER_EDGE_DETECTION == 6
        float3 I = CEdge_GetFreiChen(CShade_SampleColorTex, Input.Tex0, Delta).rgb;
    #else
        float3 I = CEdge_GetMagnitudeRGB(F.Gx.rgb, F.Gy.rgb);
    #endif

    if (_WeightMode == 1)
    {
        I = CColor_RGBtoLuma(I, 0);
        F.Gx.rgb = CColor_RGBtoLuma(F.Gx.rgb, 0);
        F.Gy.rgb = CColor_RGBtoLuma(F.Gy.rgb, 0);
    }

    // Initialize variables for Output
    float4 Base = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0.xy);
    float4 OutputColor = Base;

    switch (_DisplayMode)
    {
        case 0: // Contour
            float3 BackgroundColor = lerp(Base.rgb, _BackColor.rgb, _BackColor.a);
            float3 Mask = saturate(((I * _ColorSensitivity) - Threshold) * InverseRange);
            OutputColor.rgb = lerp(BackgroundColor, _FrontColor.rgb, Mask * _FrontColor.a);
            break;
        case 1: // Quadrate
            OutputColor.rgb = lerp(OutputColor.rgb, CMath_SNORMtoUNORM_FLT3(F.Gx.rgb), Grid.Index == 1);
            OutputColor.rgb = lerp(OutputColor.rgb, I.rgb, Grid.Index == 2);
            OutputColor.rgb = lerp(OutputColor.rgb, CMath_SNORMtoUNORM_FLT3(F.Gy.rgb), Grid.Index == 3);
            break;
        case 2: // Magnitude
            OutputColor.rgb = I.rgb;
            break;
        case 3: // X Gradient
            OutputColor.rgb = CMath_SNORMtoUNORM_FLT3(F.Gx.rgb);
            break;
        case 4: // Y Gradient
            OutputColor.rgb = CMath_SNORMtoUNORM_FLT3(F.Gy.rgb);
            break;
        default:
            OutputColor.rgb = Base.rgb;
            break;
    }

    Output = CBlend_OutputChannels(OutputColor.rgb, _CShade_AlphaFactor);
}

technique CShade_KinoContour
<
    ui_label = "CShade / Keijiro Takahashi / KinoContour";
    ui_tooltip = "Keijiro Takahashi's contour line filter.";
>
{
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
