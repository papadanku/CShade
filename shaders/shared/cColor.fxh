
#include "cMath.fxh"

#if !defined(INCLUDE_CCOLOR)
    #define INCLUDE_CCOLOR

    static const float3 CColor_Rec709_Coefficients = float3(0.2126, 0.7152, 0.0722);

    /*
        https://microsoft.github.io/DirectX-Specs/
    */

    float4 CColor_SRGBToLinear(float4 Color)
    {
        Color = (Color <= 0.04045) ? Color / 12.92 : pow((Color + 0.055) / 1.055, 2.4);
        return Color;
    }

    float4 CColor_LinearToSRGB(float4 Color)
    {
        Color = (Color <=  0.0031308) ? 12.92 * Color : 1.055 * pow(Color, 1.0 / 2.4) - 0.055;
        return Color;
    }

    /*
        https://printtechnologies.org/standards/files/pdf-reference-1.6-addendum-blend-modes.pdf
    */

    float3 CColor_BlendNormal(float3 B, float3 S)
    {
        return S;
    }

    float3 CColor_BlendMultiply(float3 B, float3 S)
    {
        return B * S;
    }

    float3 CColor_BlendScreen(float3 B, float3 S)
    {
        return B + S - (B * S);
    }

    float3 CColor_BlendHardLight(float3 B, float3 S)
    {
        float3 Blend = (S <= 0.5)
        ? CColor_BlendMultiply(B, 2.0 * S)
        : CColor_BlendScreen(B, 2.0 * S - 1.0);
        return Blend;
    }

    float3 CColor_BlendOverlay(float3 B, float3 S)
    {
        return CColor_BlendHardLight(S, B);
    }

    float3 CColor_BlendDarken(float3 B, float3 S)
    {
        return min(B, S);
    }

    float3 CColor_BlendLighten(float3 B, float3 S)
    {
        return max(B, S);
    }

    float3 CColor_BlendColorDodge(float3 B, float3 S)
    {
        float3 Blend = (S < 1.0) ? min(1.0, B / (1.0 - S)) : 1.0;
        return Blend;
    }

    float3 CColor_BlendColorBurn(float3 B, float3 S)
    {
        float3 Blend = (S == 0.0) ? 0.0 : 1.0 - min(1.0, (1.0 - B) / S);
        return Blend;
    }

    float3 CColor_BlendSoftLight(float3 B, float3 S)
    {
        float3 D = (B <= 0.25) ? ((16.0 * B - 12.0) * B + 4.0) * B : sqrt(B);
        float3 Blend = (S <= 0.5)
        ? B - (1.0 - 2.0 * S) * B * (1.0 - B)
        : B + (2.0 * S - 1.0) * (D - B);
        return Blend;
    }

    float3 CColor_BlendDifference(float3 B, float3 S)
    {
        return abs(B - S);
    }

    float3 CColor_BlendExclusion(float3 B, float3 S)
    {
        return B + S - 2.0 * B * S;
    }

    float3 CColor_Blend(float3 B, float3 S, int Blend)
    {
        switch (Blend)
        {
            case 0: // Normal
                return CColor_BlendNormal(B, S);
            case 1: // Multiply
                return CColor_BlendMultiply(B, S);
            case 2: // Screen
                return CColor_BlendScreen(B, S);
            case 3: // Overlay
                return CColor_BlendOverlay(B, S);
            case 4: // Darken
                return CColor_BlendDarken(B, S);
            case 5: // Lighten
                return CColor_BlendLighten(B, S);
            case 6: // Color Dodge
                return CColor_BlendColorDodge(B, S);
            case 7: // Color Burn
                return CColor_BlendColorBurn(B, S);
            case 8: // Hard Light
                return CColor_BlendHardLight(B, S);
            case 9: // Soft Light
                return CColor_BlendSoftLight(B, S);
            case 10: // Difference
                return CColor_BlendDifference(B, S);
            case 11: // Exclusion
                return CColor_BlendExclusion(B, S);
            default:
                return CColor_BlendNormal(B, S);
        }
    }

    float3 CColor_GetSumChromaticity(float3 Color, int Method)
    {
        float Sum = 0.0;
        float White = 0.0;

        switch(Method)
        {
            case 0: // Length
                Sum = length(Color);
                White = 1.0 / sqrt(3.0);
                break;
            case 1: // Dot3 Average
                Sum = dot(Color, 1.0 / 3.0);
                White = 1.0;
                break;
            case 2: // Dot3 Sum
                Sum = dot(Color, 1.0);
                White = 1.0 / 3.0;
                break;
            case 3: // Max
                Sum = max(max(Color.r, Color.g), Color.b);
                White = 1.0;
                break;
        }

        float3 Chromaticity = (Sum == 0.0) ? White : Color / Sum;
        return Chromaticity;
    }

    /*
        Ratio-based chromaticity
    */

    float2 CColor_GetRatioRG(float3 Color)
    {
        float2 Ratio = (Color.z == 0.0) ? 1.0 : Color.xy / Color.zz;
        // x / (x + 1.0) normalizes to [0, 1] range
        return Ratio / (Ratio + 1.0);
    }

    /*
        Color-space conversion
        ---
        https://github.com/colour-science/colour
        ---
        Copyright 2013 Colour Developers

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

        3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
    */

    float3 CColor_GetYCOCGfromRGB(float3 RGB, bool Normalize)
    {
        float3x3 M = float3x3
        (
            1.0 / 4.0, 1.0 / 2.0, 1.0 / 4.0,
            1.0 / 2.0, 0.0, -1.0 / 2.0,
            -1.0 / 4.0, 1.0 / 2.0, -1.0 / 4.0
        );

        RGB = (Normalize) ? mul(M, RGB) + 0.5 : mul(M, RGB);
        return RGB;
    }

    float3 CColor_GetRGBfromYCOCG(float3 YCoCg)
    {
        float3x3 M = float3x3
        (
            1.0, 1.0, -1.0,
            1.0, 0.0, 1.0,
            1.0, -1.0, -1.0
        );

        return mul(M, YCoCg);
    }

    float3 CColor_GetHSVfromRGB(float3 Color)
    {
        float MinRGB = min(min(Color.r, Color.g), Color.b);
        float MaxRGB = max(max(Color.r, Color.g), Color.b);

        // Calculate Value (V)
        float Delta = MaxRGB - MinRGB;

        // Calculate Hue (H)
        float3 DeltaRGB = (((MaxRGB - Color.rgb) / 6.0) + (Delta / 2.0)) / Delta;
        float Hue = DeltaRGB.b - DeltaRGB.g;
        Hue = (MaxRGB == Color.g) ? (1.0 / 3.0) + DeltaRGB.r - DeltaRGB.b : Hue;
        Hue = (MaxRGB == Color.b) ? (2.0 / 3.0) + DeltaRGB.g - DeltaRGB.r : Hue;
        Hue = (Hue < 0.0) ? Hue + 1.0 : (Hue > 1.0) ? Hue - 1.0 : Hue;

        // Calcuate Saturation (S)
        float Saturation = Delta / MaxRGB;

        float3 Output = 0.0;
        Output.x = Hue;
        Output.y = Saturation;
        Output.z = MaxRGB;
        return Output;
    }

    float3 CColor_GetRGBfromHSV(float3 HSV)
    {
        float H = HSV.x * 6.0;
        float S = HSV.y;
        float V = HSV.z;

        float I = floor(H);
        float J = V * (1.0 - S);
        float K = V * (1.0 - S * (H - I));
        float L = V * (1.0 - S * (1.0 - (H - I)));
        float4 P = float4(V, J, K, L);

        float3 O = P.xwy;
        O = (I >= 1) ? P.zxy : O;
        O = (I >= 2) ? P.yxw : O;
        O = (I >= 3) ? P.yzx : O;
        O = (I >= 4) ? P.wyx : O;
        O = (I >= 5) ? P.xyz : O;
        return O;
    }

    float3 CColor_GetHSLfromRGB(float3 Color)
    {
        float MinRGB = min(min(Color.r, Color.g), Color.b);
        float MaxRGB = max(max(Color.r, Color.g), Color.b);
        float DeltaAdd = MaxRGB + MinRGB;
        float DeltaSub = MaxRGB - MinRGB;

        // Calculate Lightnes (L)
        float Lightness = DeltaAdd / 2.0;

        // Calclate Saturation (S)
        float Saturation = (Lightness < 0.5) ?  DeltaSub / DeltaAdd : DeltaSub / (2.0 - DeltaSub);

        // Calculate Hue (H)
        float3 DeltaRGB = (((MaxRGB - Color.rgb) / 6.0) + (DeltaSub / 2.0)) / DeltaSub;
        float Hue = DeltaRGB.b - DeltaRGB.g;
        Hue = (MaxRGB == Color.g) ? (1.0 / 3.0) + DeltaRGB.r - DeltaRGB.b : Hue;
        Hue = (MaxRGB == Color.b) ? (2.0 / 3.0) + DeltaRGB.g - DeltaRGB.r : Hue;
        Hue = (Hue < 0.0) ? Hue + 1.0 : (Hue > 1.0) ? Hue - 1.0 : Hue;

        float3 Output = 0.0;
        Output.x = (DeltaAdd == 0.0) ? 0.0 : Hue;
        Output.y = (DeltaAdd == 0.0) ? 0.0 : Saturation;
        Output.z = Lightness;
        return Output;
    }

    /*
        This code is based on the algorithm described in the following paper:
        Author(s): Joost van de Weijer, T. Gevers
        Title: "Robust optical flow from photometric invariants"
        Year: 2004
        DOI: 10.1109/ICIP.2004.1421433
        Link: https://www.researchgate.net/publication/4138051_Robust_optical_flow_from_photometric_invariants
    */

    float2 CColor_GetSphericalRG(float3 Color)
    {
        const float HalfPi = 1.0 / acos(0.0);

        // Precalculate (x*x + y*y)^0.5 and (x*x + y*y + z*z)^0.5
        float L1 = length(Color.rg);
        float L2 = length(Color.rgb);

        float2 Angles = 0.0;
        Angles[0] = (L1 == 0.0) ? 1.0 / sqrt(2.0) : Color.g / L1;
        Angles[1] = (L2 == 0.0) ? 1.0 / sqrt(3.0) : L1 / L2;

        return saturate(asin(abs(Angles)) * HalfPi);
    }

    float3 CColor_GetHSIfromRGB(float3 Color)
    {
        float3 O = Color.rrr;
        O += (Color.ggg * float3(-1.0, 1.0, 1.0));
        O += (Color.bbb * float3(0.0, -2.0, 1.0));
        O *= rsqrt(float3(2.0, 6.0, 3.0));

        float H = atan(O.x/O.y) / acos(0.0);
        H = (H * 0.5) + 0.5; // We also scale to [0,1] range
        float S = length(O.xy);
        float I = O.z;

        return float3(H, S, I);
    }

    /*
        Luminance methods
    */
    float CColor_GetLuma(float3 Color, int Method)
    {
        switch(Method)
        {
            case 0:
                // Average
                return dot(Color.rgb, 1.0 / 3.0);
            case 1:
                // Min
                return min(Color.r, min(Color.g, Color.b));
            case 2:
                // Median
                return max(min(Color.r, Color.g), min(max(Color.r, Color.g), Color.b));
            case 3:
                // Max
                return max(Color.r, max(Color.g, Color.b));
            case 4:
                // Length
                return length(Color.rgb) * rsqrt(3.0);
            case 5:
                // Min+Max
                return lerp(min(Color.r, min(Color.g, Color.b)), max(Color.r, max(Color.g, Color.b)), 0.5);
            default:
                return 0.5;
        }
    }

    /*
        Copyright (c) 2020 Björn Ottosson

        https://bottosson.github.io/posts/oklab/

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    */

    static const float3x3 CColor_OKLABfromRGB_M1 = float3x3
    (
        float3(+0.4122214708, +0.5363325363, +0.0514459929),
        float3(+0.2119034982, +0.6806995451, +0.1073969566),
        float3(+0.0883024619, +0.2817188376, +0.6299787005)
    );

    static const float3x3 CColor_OKLABfromRGB_M2 = float3x3
    (
        float3(+0.2104542553, +0.7936177850f, -0.0040720468),
        float3(+1.9779984951, -2.4285922050f, +0.4505937099),
        float3(+0.0259040371, +0.7827717662f, -0.8086757660)
    );

    float3 CColor_GetOKLABfromRGB(float3 Color)
    {
        float3 LMS = mul(CColor_OKLABfromRGB_M1, Color);
        LMS = pow(abs(LMS), 1.0 / 3.0);
        LMS = mul(CColor_OKLABfromRGB_M2, LMS);
        return LMS;
    };

    static const float3x2 CColor_RGBfromOKLAB_M1 = float3x2
    (
        float2(+0.3963377774, +0.2158037573),
        float2(-0.1055613458, -0.0638541728),
        float2(-0.0894841775, -1.2914855480)
    );

    static const float3x3 CColor_RGBfromOKLAB_M2 = float3x3
    (
        float3(+4.0767416621, -3.3077115913, +0.2309699292),
        float3(-1.2684380046, +2.6097574011, -0.3413193965),
        float3(-0.0041960863, -0.7034186147, +1.7076147010)
    );

    float3 CColor_GetRGBfromOKLAB(float3 OKLab)
    {
        float3 LMS = OKLab.xxx + mul(CColor_RGBfromOKLAB_M1, OKLab.yz);
        LMS = LMS * LMS * LMS;
        LMS = mul(CColor_RGBfromOKLAB_M2, LMS);
        return LMS;
    }

    float3 CColor_GetOKLCHfromOKLAB(float3 OKLab)
    {
        float3 OKLch = 0.0;
        OKLch.x = OKLab.x;
        OKLch.y = length(OKLab.yz);
        OKLch.z = atan2(OKLab.z, OKLab.y);
        return OKLch;
    }

    float3 CColor_GetOKLABfromOKLCH(float3 OKLch)
    {
        float3 OKLab = 0.0;
        OKLab.x = OKLch.x;
        OKLab.y = OKLch.y * cos(OKLch.z);
        OKLab.z = OKLch.y * sin(OKLch.z);
        return OKLab;
    }

    float3 CColor_GetOKLCHfromRGB(float3 Color)
    {
        return CColor_GetOKLCHfromOKLAB(CColor_GetOKLABfromRGB(Color));
    }

    float3 CColor_GetRGBfromOKLCH(float3 OKLch)
    {
        return CColor_GetRGBfromOKLAB(CColor_GetOKLABfromOKLCH(OKLch));
    }

    /*
        LogC conversion
        https://www.arri.com/en/learn-help/learn-help-camera-system/image-science/log-c
    */

    struct CColor_LogC_Constants
    {
        float A, B, C, S, T;
    };

    CColor_LogC_Constants CColor_GetLogC_Constants()
    {
        CColor_LogC_Constants Output;
        const float A = (exp2(18.0) - 16.0) / 117.45;
        const float B = (1023.0 - 95.0) / 1023.0;
        const float C = 95.0 / 1023.0;
        const float S = (7.0 * log(2.0) * exp2(7.0 - 14.0 * C / B)) / (A * B);
        const float T = (exp2(14.0 * (-C / B) + 6.0) - 64.0) / A;
        Output.A = A;
        Output.B = B;
        Output.C = C;
        Output.S = S;
        Output.T = T;
        return Output;
    }

    // LogC4 Curve Encoding Function
    float3 CColor_EncodeLogC(float3 Color)
    {
        CColor_LogC_Constants LogC = CColor_GetLogC_Constants();
        float3 A = (Color - LogC.T) / LogC.S;
        float3 B = (log2(LogC.A * Color + 64.0) - 6.0) / 14.0 * LogC.B + LogC.C;
        return lerp(B, A, Color < LogC.T);
    }

    // LogC4 Curve Decoding Function
    float3 CColor_DecodeLogC(float3 Color)
    {
        CColor_LogC_Constants LogC = CColor_GetLogC_Constants();
        float3 A = Color * LogC.S + LogC.T;
        float3 P = 14.0 * (Color - LogC.C) / LogC.B + 6.0;
        float3 B = (exp2(P) - 64.0) / LogC.A;

        return lerp(B, A, Color < 0.0);
    }

    /*
        https://github.com/BradLarson/GPUImage3

        Copyright (c) 2018, Brad Larson and Janie Clayton.
        All rights reserved.

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

        Neither the name of the GPUImage framework nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    */

    static const float3x3 CColor_RGBtoYIQ = float3x3
    (
        float3(0.299, 0.587, 0.114),
        float3(0.596, -0.274, -0.322),
        float3(0.212, -0.523, 0.311)
    );

    static const float3x3 CColor_YIQtoRGB = float3x3
    (
        float3(1.0, 0.956, 0.621),
        float3(1.0, -0.272, -0.647),
        float3(1.0, -1.105, 1.702)
    );

    float3 CColor_GetYIQfromRGB(float3 Color)
    {
        return mul(CColor_RGBtoYIQ, Color);
    }

    float3 CColor_GetRGBfromYIQ(float3 Color)
    {
        return mul(CColor_YIQtoRGB, Color);
    }

    /*
        Modification of Jasper's color grading tutorial
        https://catlikecoding.com/unity/tutorials/custom-srp/color-grading/

        MIT No Attribution (MIT-0)

        Copyright 2021 Jasper Flick

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    */

    void CColor_ApplyColorGrading(
        inout float3 Color,
        float Lightness, // [0.0, N); default = 0.0
        float HueShift, // [-1.0, 1.0); default = 0.0
        float Saturation, // [-1.0, 1.0); default = 0.0
        float Contrast, // [-1.0, 1.0); default = 0.0
        float3 ColorFilter, // [0.0, 1.0); default = 1.0
        float Temperature, // [-1.0, 1.0); default = 0.0
        float Tint, // [-1.0, 1.0); default = 0.0
        float3 Shadows, // [0.0, 1.0); default = float3(0.5, 0.5, 0.5)
        float3 Highlights, // [0.0, 1.0); default = float3(0.5, 0.5, 0.5)
        float Balance, // [-1.0, 1.0); default = 0.0
        float3 MixRed, // [0.0, 1.0); default = float3(1.0, 0.0, 0.0)
        float3 MixGreen, // [0.0, 1.0); default = float3(0.0, 1.0, 0.0)
        float3 MixBlue, // [0.0, 1.0); default = float3(0.0, 0.0, 1.0)
        float3 MidtoneShadowColor, // [0.0, 1.0); default = float3(1.0, 1.0, 1.0)
        float3 MidtoneColor, // [0.0, 1.0); default = float3(1.0, 1.0, 1.0)
        float3 MidtoneHightlightColor, // [0.0, 1.0); default = float3(1.0, 1.0, 1.0)
        float MidtoneShadowStart, // [0.0, 1.0); default = 0.0
        float MidtoneShadowEnd, // [0.0, 1.0); default = 0.3
        float MidtoneHighlightStart, // [0.0, 1.0); default = 0.55
        float MidtoneHighlightEnd // [0.0, 1.0); default = 1.0
    )
    {
        // Constants
        const float ACEScc_MIDGRAY = 0.4135884;

        // Convert user-friendly uniform settings
        float3x3 ChannelMixMat = float3x3(MixRed, MixGreen, MixBlue);
        Lightness += 1.0;
        Saturation += 1.0;
        HueShift *= CMath_GetPi();
        Contrast += 1.0;
        Temperature /= 10.0;
        Tint /= 10.0;

        // Convert RGB to OKLab
        Color = CColor_GetOKLABfromRGB(Color);

        // Apply temperature shift
        Color.z += Temperature;

        // Apply tint shift
        Color.y += Tint;

        // Convert OKLab to OKLch
        Color = CColor_GetOKLCHfromOKLAB(Color);

        // Apply lightness
        Color.x *= Lightness;

        // Apply saturation
        Color.y *= Saturation;

        // Apply hue shift
        Color.z += HueShift;

        // Convert OKLch to RGB
        Color = CColor_GetRGBfromOKLCH(Color);

        // Apply color filter
        Color *= ColorFilter;

        // Apply contrast
        Color = CColor_EncodeLogC(Color);
        Color = (Color - ACEScc_MIDGRAY) * Contrast + ACEScc_MIDGRAY;
        Color = CColor_DecodeLogC(Color);
        Color = max(Color, 0.0);

        // Apply gamma-space split-toning
        Color = pow(abs(Color), 1.0 / 2.2);
        float T = saturate(CColor_GetLuma(Color, 0) + Balance);
        float3 SplitShadows = lerp(0.5, Shadows, 1.0 - T);
        float3 SplitHighlights = lerp(0.5, Highlights, T);
        Color = CColor_BlendSoftLight(Color, SplitShadows);
        Color = CColor_BlendSoftLight(Color, SplitHighlights);
        Color = pow(abs(Color), 2.2);

        // Apply channel mixer
        Color = mul(ChannelMixMat, Color);

        // Apply midtones
        float Luminance = CColor_GetLuma(Color, 0);
        float3 MidtoneWeights = 0.0;
        // Shadow weight
        MidtoneWeights[0] = 1.0 - smoothstep(MidtoneShadowStart, MidtoneShadowEnd, Luminance);
        // Highlights weight
        MidtoneWeights[1] = smoothstep(MidtoneHighlightStart, MidtoneHighlightEnd, Luminance);
        // Midtones weight
        MidtoneWeights[2] = 1.0 - MidtoneWeights[0] - MidtoneWeights[1];

        float3x3 MidtoneColorMatrix = float3x3
        (
            MidtoneShadowColor,
            MidtoneColor,
            MidtoneHightlightColor
        );

        Color *= mul(MidtoneWeights, MidtoneColorMatrix);
    }
#endif
