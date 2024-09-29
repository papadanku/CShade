#define CSHADE_CONTOUR

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

uniform int _Method <
    ui_label = "Edge Detection Kernel";
    ui_type = "combo";
    ui_items = "ddx(),ddy()\0Sobel: Bilinear 3x3\0Prewitt: Bilinear 5x5\0Sobel: Bilinear 5x5\0Prewitt: 3x3\0Scharr: 3x3\0Frei-Chen\0";
> = 1;

uniform int _WeightMode <
    ui_label = "Edge Weighting Mode";
    ui_type = "combo";
    ui_items = "Single-Channel\0Multi-Channel\0";
> = 0;

uniform float _Threshold <
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.05;

uniform float _InverseRange <
    ui_label = "Inverse Range";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.05;

uniform float _ColorSensitivity <
    ui_label = "Color Sensitivity";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

uniform float4 _FrontColor <
    ui_label = "Front Color";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _BackColor <
    ui_label = "Back Color";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

uniform int _DisplayMode <
    ui_label = "Display Mode";
    ui_type = "radio";
    ui_items = "Output\0Mask\0";
> = 0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#include "shared/cEdge.fxh"

/*
    [Pixel Shaders]
*/

float3 GetColorFromGradient(CEdge_Gradient Input)
{
    float3 Color = sqrt((Input.Ix.rgb * Input.Ix.rgb) + (Input.Iy.rgb * Input.Iy.rgb));
    if (_WeightMode == 1)
    {
        return Color;
    }
    else
    {
        return CColor_GetLuma(Color, 3);
    }
}

float3 GetColor(float4 Input)
{
    if (_WeightMode == 1)
    {
        return Input.rgb;
    }
    else
    {
        return CColor_GetLuma(Input.rgb, 3);
    }
}

float3 PS_Grad(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 I = 0.0;

    switch(_Method)
    {
        case 0: // ddx(), ddy()
            I = GetColorFromGradient(CEdge_GetDDXY(CShade_SampleColorTex, Input.Tex0));
            break;
        case 1: // Bilinear 3x3 Sobel
            I = GetColorFromGradient(CEdge_GetBilinearSobel3x3(CShade_SampleColorTex, Input.Tex0));
            break;
        case 2: // Bilinear 5x5 Prewitt
            I = GetColorFromGradient(CEdge_GetBilinearPrewitt5x5(CShade_SampleColorTex, Input.Tex0));
            break;
        case 3: // Bilinear 5x5 Sobel by CeeJayDK
            I = GetColorFromGradient(CEdge_GetBilinearSobel5x5(CShade_SampleColorTex, Input.Tex0));
            break;
        case 4: // 3x3 Prewitt
            I = GetColorFromGradient(CEdge_GetPrewitt3x3(CShade_SampleColorTex, Input.Tex0));
            break;
        case 5: // 3x3 Scharr
            I = GetColorFromGradient(CEdge_GetScharr3x3(CShade_SampleColorTex, Input.Tex0));
            break;
        case 6: // Frei-Chen
            I = GetColor(CEdge_GetFreiChen(CShade_SampleColorTex, Input.Tex0));
            break;
    }

    // Getting textures
    float3 Base = CShade_BackBuffer2D(Input.Tex0.xy).rgb;
    float3 BackgroundColor = lerp(Base.rgb, _BackColor.rgb, _BackColor.a);

    if (_DisplayMode == 1)
    {
        return I;
    }

    // Thresholding
    I = I * _ColorSensitivity;
    float3 Mask = saturate((I - _Threshold) * _InverseRange);
    return lerp(BackgroundColor, _FrontColor.rgb, Mask * _FrontColor.a);
}

technique CShade_KinoContour < ui_tooltip = "Keijiro Takahashi | Contour line filter"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Grad;
    }
}
