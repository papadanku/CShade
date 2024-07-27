
#include "shared/cShade.fxh"
#include "shared/cColor.fxh"
#include "shared/cEdge.fxh"

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

/*
    [Shader Options]
*/

uniform int _Method <
    ui_label = "Edge Detection Method";
    ui_type = "combo";
    ui_items = "ddx(),ddy()\0Sobel: Bilinear 3x3\0Prewitt: Bilinear 5x5\0Sobel: Bilinear 5x5\0Prewitt: 3x3\0Scharr: 3x3\0Frei-Chen\0";
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

/*
    [Pixel Shaders]
*/

float GetGradientLuma(CEdge_Gradient Input)
{
    return sqrt(dot(Input.Ix.rgb, Input.Ix.rgb) + dot(Input.Iy.rgb, Input.Iy.rgb));
}

float3 PS_Grad(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float I = 0.0;

    switch(_Method)
    {
        case 0: // ddx(), ddy()
            I = GetGradientLuma(CEdge_GetDDXY(CShade_SampleColorTex, Input.Tex0));
            break;
        case 1: // Bilinear 3x3 Sobel
            I = GetGradientLuma(CEdge_GetBilinearSobel3x3(CShade_SampleColorTex, Input.Tex0));
            break;
        case 2: // Bilinear 5x5 Prewitt
            I = GetGradientLuma(CEdge_GetBilinearPrewitt5x5(CShade_SampleColorTex, Input.Tex0));
            break;
        case 3: // Bilinear 5x5 Sobel by CeeJayDK
            I = GetGradientLuma(CEdge_GetBilinearSobel5x5(CShade_SampleColorTex, Input.Tex0));
            break;
        case 4: // 3x3 Prewitt
            I = GetGradientLuma(CEdge_GetPrewitt3x3(CShade_SampleColorTex, Input.Tex0));
            break;
        case 5: // 3x3 Scharr
            I = GetGradientLuma(CEdge_GetScharr3x3(CShade_SampleColorTex, Input.Tex0));
            break;
        case 6: // Frei-Chen
            I = CColor_GetLuma(CEdge_GetFreiChen(CShade_SampleColorTex, Input.Tex0).rgb, 3);
            break;
    }

    // Thresholding
    I = I * _ColorSensitivity;
    I = saturate((I - _Threshold) * _InverseRange);

    float3 Base = tex2D(CShade_SampleColorTex, Input.Tex0.xy).rgb;
    float3 BackgoundColor = lerp(Base.rgb, _BackColor.rgb, _BackColor.a);
    return lerp(BackgoundColor, _FrontColor.rgb, I * _FrontColor.a);
}

technique CShade_KinoContour
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Grad;
    }
}
