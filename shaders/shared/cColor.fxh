
#if !defined(INCLUDE_COLOR)
    #define INCLUDE_COLOR

    static const float CColor_Rec709_Coefficients = float3(0.2126, 0.7152, 0.0722);

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
        float DeltaRGB = MaxRGB - MinRGB;

        // Calculate hue
        float3 Hue = (Color.gbr - Color.brg) / DeltaRGB;
        Hue = (Hue * (60.0 / 360.0)) + (float3(0.0, 120.0, 240.0) / 360.0);
        float OutputHue = 0.0;
        OutputHue = (MaxRGB == Color.r) ? Hue.r : OutputHue;
        OutputHue = (MaxRGB == Color.g) ? Hue.g : OutputHue;
        OutputHue = (MaxRGB == Color.b) ? Hue.b : OutputHue;

        float3 Output = 0.0;
        Output.x = (DeltaRGB == 0.0) ? 0.0 : OutputHue;
        Output.y = (DeltaRGB == 0.0) ? 0.0 : DeltaRGB / MaxRGB;
        Output.z = MaxRGB;
        return Output;
    }

    float3 CColor_GetHSLfromRGB(float3 Color)
    {
        float MinRGB = min(min(Color.r, Color.g), Color.b);
        float MaxRGB = max(max(Color.r, Color.g), Color.b);
        float AddRGB = MaxRGB + MinRGB;
        float DeltaRGB = MaxRGB - MinRGB;

        float Lightness = AddRGB / 2.0;
        float Saturation = (Lightness < 0.5) ?  DeltaRGB / AddRGB : DeltaRGB / (2.0 - AddRGB);

        // Calculate hue
        float3 Hue = (Color.gbr - Color.brg) / DeltaRGB;
        Hue = (Hue * (60.0 / 360.0)) + (float3(0.0, 120.0, 240.0) / 360.0);
        float OutputHue = 0.0;
        OutputHue = (MaxRGB == Color.r) ? Hue.r : OutputHue;
        OutputHue = (MaxRGB == Color.g) ? Hue.g : OutputHue;
        OutputHue = (MaxRGB == Color.b) ? Hue.b : OutputHue;

        float3 Output = 0.0;
        Output.x = (DeltaRGB == 0.0) ? 0.0 : OutputHue;
        Output.y = (DeltaRGB == 0.0) ? 0.0 : Saturation;
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

#endif
