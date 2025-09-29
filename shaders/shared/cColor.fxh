
#include "cMath.fxh"

#if !defined(INCLUDE_CCOLOR)
    #define INCLUDE_CCOLOR

    static const float3 CColor_Rec709_Coefficients = float3(0.2126, 0.7152, 0.0722);

    /*
        https://microsoft.github.io/DirectX-Specs/
    */

    float4 CColor_SRGBtoRGB(float4 RGB)
    {
        RGB = (RGB <= 0.04045) ? RGB / 12.92 : pow((RGB + 0.055) / 1.055, 2.4);
        return RGB;
    }

    float4 CColor_RGBtoSRGB(float4 RGB)
    {
        RGB = (RGB <= 0.0031308) ? 12.92 * RGB : 1.055 * pow(RGB, 1.0 / 2.4) - 0.055;
        return RGB;
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

    float3 CColor_RGBtoChromaticityRGB(float3 RGB, int Method)
    {
        float Sum = 0.0;
        float White = 0.0;

        switch(Method)
        {
            case 0: // Length
                Sum = length(RGB);
                White = 1.0 / sqrt(3.0);
                break;
            case 1: // Dot3 Average
                Sum = dot(RGB, 1.0 / 3.0);
                White = 1.0;
                break;
            case 2: // Dot3 Sum
                Sum = dot(RGB, 1.0);
                White = 1.0 / 3.0;
                break;
            case 3: // Max
                Sum = max(max(RGB.r, RGB.g), RGB.b);
                White = 1.0;
                break;
        }

        float3 Chromaticity = (Sum == 0.0) ? White : RGB / Sum;
        return Chromaticity;
    }

    /*
        Ratio-based chromaticity
    */

    float2 CColor_RGBtoChromaticityRG(float3 RGB)
    {
        float2 Ratio = (RGB.z == 0.0) ? 1.0 : RGB.xy / RGB.zz;
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

    /*
        "Recommendation T.832 (06/2019)". p. 185 Table D.6 – Pseudocode for function FwdColorFmtConvert1().

        https://www.itu.int/rec/T-REC-T.832
    */

    float3 CColor_SRGBtoYUV444(float3 SRGB, bool Normalize)
    {
        float3 YUV;

        YUV.z = SRGB.b - SRGB.r;
        YUV.y = -SRGB.r + SRGB.g - (YUV.z * 0.5);
        YUV.x = SRGB.g - (YUV.y * 0.5);
        YUV.yz = Normalize ? CMath_SNORMtoUNORM_FLT2(YUV.yz) : YUV.yz;

        return YUV;
    }

    /*
        Malvar, H., & Sullivan, G. (2003). YCoCg-R: A color space with RGB reversibility and low dynamic range. ISO/IEC JTC1/SC29/WG11 and ITU-T SG16 Q, 6.

        https://www.microsoft.com/en-us/research/publication/ycocg-r-a-color-space-with-rgb-reversibility-and-low-dynamic-range/?msockid=304d3b086ecf61db06e32ea86fb06088
    */

    float3 CColor_SRGBtoYCOCGR(float3 SRGB, bool NormalizeOutput)
    {
        float3 YCoCgR;
        float Temp;

        YCoCgR.y = SRGB.r - SRGB.b;
        Temp = SRGB.b + (YCoCgR.y * 0.5);
        YCoCgR.z = SRGB.g - Temp;
        YCoCgR.x = Temp + (YCoCgR.z * 0.5);
        YCoCgR.yz = NormalizeOutput ? CMath_SNORMtoUNORM_FLT2(YCoCgR.yz) : YCoCgR.yz;

        return YCoCgR;
    }

    float3 CColor_YCOCGRtoSRGB(float3 YCoCgR, bool NormalizedInput)
    {
        float3 SRGB;
        float Temp;

        YCoCgR.yz = NormalizedInput ? CMath_UNORMtoSNORM_FLT2(YCoCgR.yz) : YCoCgR.yz;
        Temp = YCoCgR.x - (YCoCgR.z * 0.5);
        SRGB.g = YCoCgR.z + Temp;
        SRGB.b = Temp - (YCoCgR.y * 0.5);
        SRGB.r = SRGB.b + YCoCgR.y;

        return SRGB;
    }

    float3 CColor_RGBtoHSV(float3 RGB)
    {
        float MinRGB = min(min(RGB.r, RGB.g), RGB.b);
        float MaxRGB = max(max(RGB.r, RGB.g), RGB.b);
        float Chroma = MaxRGB - MinRGB;

        // Calcuate Saturation (S)
        float Saturation = Chroma / MaxRGB;

        // Calculate Hue (H)
        float Hue;

        if (Chroma == 0)
        {
            Hue = 0.0;
        }
        else if (MaxRGB == RGB.r)
        {
            Hue = 60.0 * CMath_GetModulus_FLT1((RGB.g - RGB.b) / Chroma, 6.0);
        }
        else if (MaxRGB == RGB.g)
        {
            Hue = 60.0 * ((RGB.b - RGB.r) / Chroma + 2.0);
        }
        else if (MaxRGB == RGB.b)
        {
            Hue = 60.0 * ((RGB.r - RGB.g) / Chroma + 4.0);
        }

        float3 Output = 0.0;
        Output.x = Hue;
        Output.y = Saturation;
        Output.z = MaxRGB;
        return Output;
    }

    float3 CColor_HSVtoRGB(
        float3 HSV // H: [0, 360), S: [0, 1), V: [0, 1)
    )
    {
        float Chroma = HSV.y * HSV.z;
        float HPrime = CMath_GetModulus_FLT1(HSV.x / 60.0, 6.0);
        float XValue = Chroma * (1.0 - abs(CMath_GetModulus_FLT1(HPrime, 2.0) - 1.0));
        float MValue = HSV.z - Chroma;

        float3 RGB;
        float3 CX = float3(Chroma, XValue, 0.0);
        int Section = (int)floor(HPrime);

        switch (Section)
        {
            case 0:
                RGB = CX.xyz;
                break;
            case 1:
                RGB = CX.yxz;
                break;
            case 2:
                RGB = CX.zxy;
                break;
            case 3:
                RGB = CX.zyx;
                break;
            case 4:
                RGB = CX.yzx;
                break;
            case 5:
                RGB = CX.xzy;
                break;
            default:
                RGB = CX.zzz;
                break;
        }

        return RGB + MValue;
    }

    float3 CColor_RGBtoHSL(float3 RGB)
    {
        float MinRGB = min(min(RGB.r, RGB.g), RGB.b);
        float MaxRGB = max(max(RGB.r, RGB.g), RGB.b);
        float DeltaAdd = MaxRGB + MinRGB;
        float DeltaSub = MaxRGB - MinRGB;

        // Calculate Lightnes (L)
        float Lightness = DeltaAdd / 2.0;

        // Calclate Saturation (S)
        float Saturation = (Lightness < 0.5) ?  DeltaSub / DeltaAdd : DeltaSub / (2.0 - DeltaSub);

        // Calculate Hue (H)
        float3 DeltaRGB = (((MaxRGB - RGB.rgb) / 6.0) + (DeltaSub / 2.0)) / DeltaSub;
        float Hue = DeltaRGB.b - DeltaRGB.g;
        Hue = (MaxRGB == RGB.g) ? (1.0 / 3.0) + DeltaRGB.r - DeltaRGB.b : Hue;
        Hue = (MaxRGB == RGB.b) ? (2.0 / 3.0) + DeltaRGB.g - DeltaRGB.r : Hue;
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

        https://www.researchgate.net/publication/4138051_Robust_optical_flow_from_photometric_invariants
    */

    float3 CColor_RGBtoSphericalRGB(float3 RGB)
    {
        const float InvPi = 1.0 / acos(-1.0);

        // Precalculate (x*x + y*y)^0.5 and (x*x + y*y + z*z)^0.5
        float L1 = length(RGB.xyz);
        float L2 = length(RGB.xy);

        // .x = radius; .y = inclination; .z = azimuth
        float3 RIA;
        RIA.x = L1 / sqrt(3.0);
        RIA.y = (L1 == 0.0) ? 1.0 / sqrt(3.0) : saturate(RGB.z / L1);
        RIA.z = (L2 == 0.0) ? 1.0 / sqrt(2.0) : saturate(RGB.x / L2);

        // Scale the angles to [-1.0, 1.0) range
        RIA.yz = CMath_UNORMtoSNORM_FLT2(RIA.yz);

        // Calculate inclination and azimuth and normalize to [0.0, 1.0)
        RIA.yz = acos(RIA.yz) * InvPi;

        return RIA;
    }

    float3 CColor_RGBtoHSI(float3 RGB)
    {
        float3 O = RGB.rrr;
        O += (RGB.ggg * float3(-1.0, 1.0, 1.0));
        O += (RGB.bbb * float3(0.0, -2.0, 1.0));
        O *= rsqrt(float3(2.0, 6.0, 3.0));

        float H = atan(O.x/O.y) / acos(0.0);
        H = CMath_SNORMtoUNORM_FLT1(H); // We also scale to [0, 1) range
        float S = length(O.xy);
        float I = O.z;

        return float3(H, S, I);
    }

    /*
        Luminance methods
    */
    float CColor_RGBtoLuma(float3 RGB, int Method)
    {
        switch(Method)
        {
            case 0:
                // Average
                return dot(RGB.rgb, 1.0 / 3.0);
            case 1:
                // Min
                return min(RGB.r, min(RGB.g, RGB.b));
            case 2:
                // Median
                return max(min(RGB.r, RGB.g), min(max(RGB.r, RGB.g), RGB.b));
            case 3:
                // Max
                return max(RGB.r, max(RGB.g, RGB.b));
            case 4:
                // Length
                return length(RGB.rgb) * rsqrt(3.0);
            case 5:
                // Min+Max
                return lerp(min(RGB.r, min(RGB.g, RGB.b)), max(RGB.r, max(RGB.g, RGB.b)), 0.5);
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
        float3(+0.2104542553, +0.7936177850, -0.0040720468),
        float3(+1.9779984951, -2.4285922050, +0.4505937099),
        float3(+0.0259040371, +0.7827717662, -0.8086757660)
    );

    float3 CColor_RGBtoOKLAB(float3 RGB)
    {
        float3 LMS = mul(CColor_OKLABfromRGB_M1, RGB);
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

    float3 CColor_OKLABtoRGB(float3 OKLab)
    {
        float3 LMS = OKLab.xxx + mul(CColor_RGBfromOKLAB_M1, OKLab.yz);
        LMS = LMS * LMS * LMS;
        LMS = mul(CColor_RGBfromOKLAB_M2, LMS);
        return LMS;
    }

    float3 CColor_OKLABtoOKLCH(float3 OKLab)
    {
        const float Pi = CMath_GetPi();
        float3 OKLch = 0.0;
        OKLch.x = OKLab.x;
        OKLch.y = length(OKLab.yz);
        OKLch.z = clamp(atan2(OKLab.z, OKLab.y), -Pi, Pi);
        return OKLch;
    }

    float3 CColor_OKLCHtoOKLAB(float3 OKLch)
    {
        float3 OKLab = 0.0;
        OKLab.x = OKLch.x;
        OKLab.y = OKLch.y * cos(OKLch.z);
        OKLab.z = OKLch.y * sin(OKLch.z);
        return OKLab;
    }

    float3 CColor_RGBtoOKLCH(float3 RGB)
    {
        return CColor_OKLABtoOKLCH(CColor_RGBtoOKLAB(RGB));
    }

    float3 CColor_OKLCHtoRGB(float3 OKLch)
    {
        return CColor_OKLABtoRGB(CColor_OKLCHtoOKLAB(OKLch));
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
        const float A = (pow(2.0, 18.0) - 16.0) / 117.45;
        const float B = (1023.0 - 95.0) / 1023.0;
        const float C = 95.0 / 1023.0;
        const float S = (7.0 * log(2.0) * pow(2.0, 7.0 - 14.0 * C / B)) / (A * B);
        const float T = (pow(2.0, 14.0 *(-C / B) + 6.0) - 64.0) / A;
        Output.A = A;
        Output.B = B;
        Output.C = C;
        Output.S = S;
        Output.T = T;
        return Output;
    }

    float3 CColor_EncodeLogC_Log2(float3 X)
    {
        return log(X) / log(2.0);
    }

    // LogC4 Curve Encoding Function
    float3 CColor_EncodeLogC(float3 X)
    {
        CColor_LogC_Constants LogC = CColor_GetLogC_Constants();

        float3 Out1 = (X - LogC.T) / LogC.S;
        float3 Out2 = (CColor_EncodeLogC_Log2(LogC.A * X + 64.0) - 6.0) / 14.0 * LogC.B + LogC.C;
        float3 Output = (X < LogC.T) ? Out1: Out2;

        return Output;
    }

    // LogC4 Curve Decoding Function
    float3 CColor_DecodeLogC(float3 X)
    {
        CColor_LogC_Constants LogC = CColor_GetLogC_Constants();

        float3 Out1 = X * LogC.S + LogC.T;
        float3 P = 14.0 * (X - LogC.C) / LogC.B + 6.0;
        float3 Out2 = (pow(2.0, P) - 64.0) / LogC.A;
        float3 Output = (X < 0.0) ? Out1 : Out2;

        return Output;
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

    float3 CColor_RGBtoYIQ(float3 RGB)
    {
        return mul(CColor_RGBtoYIQ, RGB);
    }

    float3 CColor_YIQtoRGB(float3 RGB)
    {
        return mul(CColor_YIQtoRGB, RGB);
    }

    /*
        The MIT License (MIT)

        Copyright (c) 2015 Microsoft

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    */

    /*
        The Reinhard tone operator. Typically, the value of K is 1.0, but you can adjust exposure by 1/K.
        I.e. CColor_ApplyReinhard(x, 0.5) == CColor_ApplyReinhard(x * 2.0, 1.0)
    */

    float3 CColor_ApplyReinhard(float3 HDR, float K)
    {
        return HDR / (HDR + K);
    }

    // The inverse of Reinhard
    float3 CColor_ApplyInverseReinhard(float3 SDR, float K)
    {
        return K * SDR / (K - SDR);
    }

    /*
        Reinhard-Squared

        This has some nice properties that improve on basic Reinhard.  Firstly, it has a "toe"--that nice,
        parabolic upswing that enhances contrast and color saturation in darks.  Secondly, it has a long
        shoulder giving greater detail in highlights and taking longer to desaturate.  It's invertible, scales
        to HDR displays, and is easy to control.

        The default constant of 0.25 was chosen for two reasons.  It maps closely to the effect of Reinhard
        with a constant of 1.0.  And with a constant of 0.25, there is an inflection point at 0.25 where the
        curve touches the line y=x and then begins the shoulder.

        Note:  If you are currently using ACES and you pre-scale by 0.6, then k=0.30 looks nice as an alternative
        without any other adjustments.
    */

    float3 CColor_ApplyReinhardSquared(float3 HDR, float K)
    {
        float3 reinhard = HDR / (HDR + K);
        return reinhard * reinhard;
    }

    float3 CColor_ApplyInverseReinhardSquared(float3 SDR, float K)
    {
        return K * (SDR + sqrt(SDR)) / (1.0 - SDR);
    }

    /*
        https://gpuopen.com/learn/optimized-reversible-tonemapper-for-resolve/
    */

    // Apply this to tonemap linear HDR color "HDR" after a sample is fetched in the resolve.
    // Note "HDR" 1.0 maps to the expected limit of low-dynamic-range monitor output.
    float3 CColor_ApplyAMDTonemap(float3 HDR)
    {
        return HDR / (max(max(HDR.r, HDR.g), HDR.b) + 1.0);
    }

    // When the filter kernel is a weighted sum of fetched colors,
    // it is more optimal to fold the weighting into the tonemap operation.
    float3 CColor_ApplyAMDTonemapWithWeight(float3 HDR, float Weight)
    {
        return HDR * (Weight / (max(max(HDR.r, HDR.g), HDR.b) + 1.0));
    }

    // Apply this to restore the linear HDR color before writing out the result of the resolve.
    float3 CColor_ApplyInverseAMDTonemap(float3 HDR)
    {
        return HDR / (1.0 - max(max(HDR.r, HDR.g), HDR.b));
    }

    float3 CColor_ApplyTonemap(float3 HDR, int Tonemapper)
    {
        switch (Tonemapper)
        {
            case 0:
                return HDR;
            case 1:
                return CColor_ApplyReinhard(HDR, 1.0);
            case 2:
                return CColor_ApplyReinhardSquared(HDR, 0.25);
            case 3:
                return CColor_ApplyAMDTonemap(HDR);
            case 4:
                return CColor_EncodeLogC(HDR);
            default:
                return HDR;
        }
    }

    float4 CColor_ApplyInverseTonemap(float4 SDR, int Tonemapper)
    {
        switch (Tonemapper)
        {
            case 0:
                SDR.rgb = SDR.rgb;
                break;
            case 1:
                SDR.rgb = CColor_ApplyInverseReinhard(SDR.rgb, 1.0);
                break;
            case 2:
                SDR.rgb = CColor_ApplyInverseReinhardSquared(SDR.rgb, 0.25);
                break;
            case 3:
                SDR.rgb = CColor_ApplyInverseAMDTonemap(SDR.rgb);
                break;
            case 4:
                SDR.rgb = CColor_DecodeLogC(SDR.rgb);
                break;
            default:
                SDR.rgb = SDR.rgb;
                break;
        }

        return SDR;
    }

#endif
