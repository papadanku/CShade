
#include "cMath.fxh"

#if !defined(INCLUDE_CCOLOR)
    #define INCLUDE_CCOLOR

    static const float3 CColor_Rec709_Coefficients = float3(0.2126, 0.7152, 0.0722);

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
        https://www.microsoft.com/en-us/research/publication/ycocg-r-a-color-space-with-rgb-reversibility-and-low-dynamic-range/
        ---
        YCoCg-R: A Color Space with RGB Reversibility and Low Dynamic Range
        Henrique S. Malvar, Gary Sullivan
        MSR-TR-2003-103 | July 2003
        ---
        Technical contribution to the H.264 Video Coding Standard. Joint Video Team (JVT) of ISO/IEC MPEG & ITU-T VCEG (ISO/IEC JTC1/SC29/WG11 and ITU-T SG16 Q.6) Document JVT-I014r3.
    */

    float2 CColor_GetCoCg(float3 Color)
    {
        float2 CoCg = 0.0;
        float2x3 MatCoCg = float2x3
        (
            float3(1.0, 0.0, -1.0),
            float3(-0.5, 1.0, -0.5)
        );

        CoCg.x = dot(Color, MatCoCg[0]);
        CoCg.y = dot(Color, MatCoCg[1]);

        return (CoCg * 0.5) + 0.5;
    }

    /*
        RGB to CrCb
        ---
        https://docs.opencv.org/4.7.0/de/d25/imgproc_color_conversions.html
    */

    float2 CColor_GetCrCb(float3 Color)
    {
        float Y = dot(Color, float3(0.299, 0.587, 0.114));
        return ((Color.br - Y) * float2(0.564, 0.713)) + 0.5;
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

    float3 CColor_GetOKLABfromRGB(float3 Color)
    {
        float3 M1[3] =
        {
            float3(+0.4122214708, +0.2119034982, +0.0883024619),
            float3(+0.5363325363, +0.6806995451, +0.2817188376),
            float3(+0.0514459929, +0.1073969566, +0.6299787005)
        };

        float3 M2[3] =
        {
            float3(+0.2104542553, +1.9779984951, +0.0259040371),
            float3(+0.7936177850, -2.4285922050, +0.7827717662),
            float3(-0.0040720468, +0.4505937099, -0.8086757660)
        };

        float3 LMS = M1[0] * Color.rrr + M1[1] * Color.ggg + M1[2] * Color.bbb;
        LMS = pow(LMS, 1.0 / 3.0);
        LMS = M2[0] * LMS.rrr + M2[1] * LMS.ggg + M2[2] * LMS.bbb;
        return LMS;
    }

    float3 CColor_GetRGBfromOKLAB(float3 OKLab)
    {
        float3 M1[2] =
        {
            float3(+0.3963377774, -0.1055613458, -0.0894841775),
            float3(+0.2158037573, -0.0638541728, -1.2914855480)
        };

        float3 M2[3] =
        {
            float3(+4.0767416621, -1.2684380046, -0.0041960863),
            float3(-3.3077115913, +2.6097574011, -0.7034186147),
            float3(+0.2309699292, -0.3413193965, +1.7076147010)
        };

        float3 LMS = OKLab.xxx + M1[0] * OKLab.yyy + M1[1] * OKLab.zzz;
        LMS = LMS * LMS * LMS;
        LMS = M2[0] * LMS.xxx + M2[1] * LMS.yyy + M2[2] * LMS.zzz;
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

    struct CCamera_LogC_Constants
    {
        float A, B, C, S, T;
    };

    CCamera_LogC_Constants CCamera_GetLogC_Constants()
    {
        CCamera_LogC_Constants Output;
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
    float3 CCamera_EncodeLogC(float3 Color)
    {
        CCamera_LogC_Constants LogC = CCamera_GetLogC_Constants();
        float3 A = (Color - LogC.T) / LogC.S;
        float3 B = (log2(LogC.A * Color + 64.0) - 6.0) / 14.0 * LogC.B + LogC.C;
        return lerp(B, A, Color < LogC.T);
    }

    // LogC4 Curve Decoding Function
    float3 CCamera_DecodeLogC(float3 Color)
    {
        CCamera_LogC_Constants LogC = CCamera_GetLogC_Constants();
        float3 A = Color * LogC.S + LogC.T;
        float3 P = 14.0 * (Color - LogC.C) / LogC.B + 6.0;
        float3 B = (exp2(P) - 64.0) / LogC.A;

        return lerp(B, A, Color < 0.0);
    }
#endif
