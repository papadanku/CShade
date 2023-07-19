#include "cGraphics.fxh"

#if !defined(CIMAGEPROCESSING_FXH)
    #define CIMAGEPROCESSING_FXH

    /*
        [Convolutions - Blur]
    */

    /*
        Linear Gaussian blur
        ---
        https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/
    */

    float GetGaussianWeight(float SampleIndex, float Sigma)
    {
        const float Pi = acos(-1.0);
        float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
        return Output * exp(-(SampleIndex * SampleIndex) / (2.0 * Sigma * Sigma));
    }

    float GetGaussianOffset(float SampleIndex, float Sigma, out float LinearWeight)
    {
        float Offset1 = SampleIndex;
        float Offset2 = SampleIndex + 1.0;
        float Weight1 = GetGaussianWeight(Offset1, Sigma);
        float Weight2 = GetGaussianWeight(Offset2, Sigma);
        LinearWeight = Weight1 + Weight2;
        return ((Offset1 * Weight1) + (Offset2 * Weight2)) / LinearWeight;
    }

    float4 GetPixelBlur(VS2PS_Quad Input, sampler2D SampleSource, bool Horizontal)
    {
        // Initialize variables
        const int KernelSize = 10;
        const float4 HShift = float4(-1.0, 0.0, 1.0, 0.0);
        const float4 VShift = float4(0.0, -1.0, 0.0, 1.0);

        float4 OutputColor = 0.0;
        float4 PSize = float2(ddx(Input.Tex0.x), ddy(Input.Tex0.y)).xyxy;

        const float Offsets[KernelSize] =
        {
            0.0, 1.490652, 3.4781995, 5.465774, 7.45339,
            9.441065, 11.42881, 13.416645, 15.404578, 17.392626,
        };

        const float Weights[KernelSize] =
        {
            0.06299088, 0.122137636, 0.10790718, 0.08633988, 0.062565096,
            0.04105926, 0.024403222, 0.013135255, 0.006402994, 0.002826693
        };

        // Sample and weight center first to get even number sides
        float TotalWeight = Weights[0];
        OutputColor = tex2D(SampleSource, Input.Tex0 + (Offsets[0] * PSize.xy)) * Weights[0];

        // Sample neighboring pixels
        for(int i = 1; i < KernelSize; i++)
        {
            const float4 Offset = (Horizontal) ? Offsets[i] * HShift: Offsets[i] * VShift;
            float4 Tex = Input.Tex0.xyxy + (Offset * PSize);
            OutputColor += tex2D(SampleSource, Tex.xy) * Weights[i];
            OutputColor += tex2D(SampleSource, Tex.zw) * Weights[i];
            TotalWeight += (Weights[i] * 2.0);
        }

        // Normalize intensity to prevent altered output
        return OutputColor / TotalWeight;
    }

    /*
        Wojciech Sterna's shadow sampling code as a screen-space convolution (http://maxest.gct-game.net/content/chss.pdf)
        ---
        Vogel disk sampling: http://blog.marmakoide.org/?p=1
        Rotated noise sampling: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare (slide 123)
    */

    float2 SampleVogel(int Index, int SamplesCount)
    {
        const float Pi = acos(-1.0);
        const float GoldenAngle = Pi * (3.0 - sqrt(5.0));
        float Radius = sqrt(float(Index) + 0.5) * rsqrt(float(SamplesCount));
        float Theta = float(Index) * GoldenAngle;

        float2 SinCosTheta = 0.0;
        SinCosTheta[0] = sin(Theta);
        SinCosTheta[1] = cos(Theta);
        return Radius * SinCosTheta;
    }

    float4 Filter3x3(sampler2D SampleSource, float2 Tex, bool DownSample)
    {
        const float3 Weights = float3(1.0, 2.0, 4.0) / 16.0;
        float2 PixelSize = float2(ddx(Tex.x), ddy(Tex.y));
        PixelSize = (DownSample) ? PixelSize * 0.5 : PixelSize;

        float4 STex[3] =
        {
            Tex.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * abs(PixelSize.xyyy)),
            Tex.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * abs(PixelSize.xyyy)),
            Tex.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * abs(PixelSize.xyyy))
        };

        float4 OutputColor = 0.0;
        OutputColor += (tex2D(SampleSource, STex[0].xy) * Weights[0]);
        OutputColor += (tex2D(SampleSource, STex[1].xy) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[2].xy) * Weights[0]);
        OutputColor += (tex2D(SampleSource, STex[0].xz) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[1].xz) * Weights[2]);
        OutputColor += (tex2D(SampleSource, STex[2].xz) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[0].xw) * Weights[0]);
        OutputColor += (tex2D(SampleSource, STex[1].xw) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[2].xw) * Weights[0]);
        return OutputColor;
    }

    /*
        [Convolutions - Edge Detection]
    */

    /*
        Linear filtered Sobel filter
    */

    struct VS2PS_Sobel
    {
        float4 HPos : SV_POSITION;
        float4 Tex0 : TEXCOORD0;
    };

    VS2PS_Sobel GetVertexSobel(APP2VS Input, float2 PixelSize)
    {
        VS2PS_Quad FSQuad = VS_Quad(Input);

        VS2PS_Sobel Output;
        Output.HPos = FSQuad.HPos;
        Output.Tex0 = FSQuad.Tex0.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * PixelSize.xyxy);
        return Output;
    }

    float2 GetPixelSobel(VS2PS_Sobel Input, sampler2D SampleSource)
    {
        float2 OutputColor0 = 0.0;
        float A = tex2D(SampleSource, Input.Tex0.xw).r * 4.0; // <-0.5, +0.5>
        float B = tex2D(SampleSource, Input.Tex0.zw).r * 4.0; // <+0.5, +0.5>
        float C = tex2D(SampleSource, Input.Tex0.xy).r * 4.0; // <-0.5, -0.5>
        float D = tex2D(SampleSource, Input.Tex0.zy).r * 4.0; // <+0.5, -0.5>
        OutputColor0.x = ((B + D) - (A + C)) / 4.0;
        OutputColor0.y = ((A + B) - (C + D)) / 4.0;
        return OutputColor0;
    }

    /*
        [Noise Generation]
    */

    /*
        Interleaved Gradient Noise Dithering
        ---
        http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx
    */

    float GetGradientNoise(float2 Position)
    {
        return frac(52.9829189 * frac(dot(Position, float2(0.06711056, 0.00583715))));
    }

    float3 GetDither(float2 Position)
    {
        return GetGradientNoise(Position) / 255.0;
    }

    /*
        [Color Processing]
    */

    float3 GetSumChromaticity(float3 Color, int Method)
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
        }

        float3 Chromaticity = (Sum == 0.0) ? White : Color / Sum;
        return Chromaticity;
    }

    /*
        Ratio-based chromaticity
    */

    float2 GetRatioRG(float3 Color)
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

    float2 GetCoCg(float3 Color)
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

    float2 GetCrCb(float3 Color)
    {
        float Y = dot(Color, float3(0.299, 0.587, 0.114));
        return ((Color.rb - Y) * float2(0.713, 0.564)) + 0.5;
    }

    /*
        RGB to saturation value.
        ---
        Golland, Polina, and Alfred M. Bruckstein. "Motion from color."
        Computer Vision and Image Understanding 68, no. 3 (1997): 346-362.
        ---
        http://www.cs.technion.ac.il/users/wwwb/cgi-bin/tr-get.cgi/1995/CIS/CIS9513.pdf
    */

    float SaturateRGB(float3 Color)
    {
        // Calculate min and max RGB
        float MinColor = min(min(Color.r, Color.g), Color.b);
        float MaxColor = max(max(Color.r, Color.g), Color.b);

        // Calculate normalized RGB
        float SatRGB = (MaxColor - MinColor) / MaxColor;
        SatRGB = (MaxColor == 0.0) ? 0.0 : SatRGB;

        return SatRGB;
    }

    float2 GetSphericalRG(float3 Color)
    {
        const float IHalfPi = 1.0 / acos(0.0);
        const float2 White = acos(rsqrt(float2(2.0, 3.0)));

        float2 DotC = 0.0;
        DotC.x = dot(Color.xy, Color.xy);
        DotC.y = dot(Color.xyz, Color.xyz);
        float2 P = (DotC == 0.0) ? White : acos(abs(Color.xz * rsqrt(DotC)));
        return saturate(P * IHalfPi);
    }
#endif
