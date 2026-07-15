
/*
    This header file provides a collection of blur-related functions and algorithms. It includes implementations for linear Gaussian blur, various downsampling techniques (Dual Kawase, Box, 6x6 with Karis optimization), an upsampling tent filter, and a 3x3 median filter. Additionally, it features an optimized, self-guided version of Joint Bilateral Upsampling. This file serves as a utility library for applying different types of blurring and resampling effects to textures.
*/

#include "cMath.fxh"

#if !defined(INCLUDE_CBLUR)
    #define INCLUDE_CBLUR

    /*
        Linear Gaussian blur

        https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/
    */

    float CBlur_GetGaussianOffset(float SampleIndex, float Sigma, out float LinearWeight)
    {
        float Offset1 = SampleIndex;
        float Offset2 = SampleIndex + 1.0;
        float Weight1 = CMath_GetGaussian1D(Offset1, Sigma);
        float Weight2 = CMath_GetGaussian1D(Offset2, Sigma);
        LinearWeight = Weight1 + Weight2;
        return ((Offset1 * Weight1) + (Offset2 * Weight2)) / LinearWeight;
    }

    float4 CBlur_GetPixelBlur(float2 Tex, sampler2D SampleSource, bool Horizontal)
    {
        // Initialize variables
        const int KernelSize = 10;
        const float4 HShift = float4(-1.0, 0.0, 1.0, 0.0);
        const float4 VShift = float4(0.0, -1.0, 0.0, 1.0);

        float4 OutputColor = 0.0;
        float4 PSize = fwidth(Tex).xyxy;

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
        OutputColor = tex2D(SampleSource, Tex + (Offsets[0] * PSize.xy)) * Weights[0];

        // Sample neighboring pixels
        for (int i = 1; i < KernelSize; i++)
        {
            const float4 Offset = (Horizontal) ? Offsets[i] * HShift: Offsets[i] * VShift;
            float4 Tex = Tex.xyxy + (Offset * PSize);
            OutputColor += tex2D(SampleSource, Tex.xy) * Weights[i];
            OutputColor += tex2D(SampleSource, Tex.zw) * Weights[i];
            TotalWeight += (Weights[i] * 2.0);
        }

        // Normalize intensity to prevent altered output
        return OutputColor / TotalWeight;
    }

    /*
        Wojciech Sterna's shadow sampling code as a screen-space convolution (http://maxest.gct-game.net/content/chss.pdf)

        Vogel disk sampling: http://blog.marmakoide.org/?p=1
        Rotated noise sampling: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare (slide 123)
    */

    float2 CBlur_SampleVogel(int Index, int SamplesCount, float Scale, float Phi)
    {
        const float GoldenAngle = CMath_GetPi() * (3.0 - sqrt(5.0));
        float Radius = Scale * sqrt(float(Index) + 0.5) * rsqrt(float(SamplesCount));
        float Theta = float(Index) * GoldenAngle + Phi;

        float2 SinCosTheta = 0.0;
        SinCosTheta[0] = sin(Theta);
        SinCosTheta[1] = cos(Theta);
        return Radius * SinCosTheta;
    }

    /*
        The MIT License (MIT) Copyright (c) Imagination Technologies Ltd.

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    */

    float4 CBlur_DownsampleDualKawase(sampler2D Image, float2 Tex)
    {
        float4 OutputColor = 0.0;

        float2 Delta = fwidth(Tex);
        float4 Tex0 = Tex.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * Delta.xyxy);

        float2 Weights = float2(1.0, 4.0) / 8.0;
        OutputColor += (tex2D(Image, Tex) * Weights[1]);
        OutputColor += (tex2D(Image, Tex0.xw) * Weights[0]);
        OutputColor += (tex2D(Image, Tex0.zw) * Weights[0]);
        OutputColor += (tex2D(Image, Tex0.xy) * Weights[0]);
        OutputColor += (tex2D(Image, Tex0.zy) * Weights[0]);

        return OutputColor;
    }

    // https://catlikecoding.com/unity/tutorials/advanced-rendering/bloom/
    float4 CBlur_DownsampleBox(sampler2D Image, float2 Tex)
    {
        float4 OutputColor = 0.0;

        float2 Delta = fwidth(Tex);
        float4 Tex0 = Tex.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * Delta.xyxy);

        float Weight = 1.0 / 4.0;
        OutputColor += (tex2D(Image, Tex0.xw) * Weight);
        OutputColor += (tex2D(Image, Tex0.zw) * Weight);
        OutputColor += (tex2D(Image, Tex0.xy) * Weight);
        OutputColor += (tex2D(Image, Tex0.zy) * Weight);

        return OutputColor;
    }

    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
    float4 CBlur_UpsampleTent(sampler2D SampleSource, float2 Tex)
    {
        // A0 B0 C0
        // A1 B1 C1
        // A2 B2 C2
        float2 Delta = fwidth(Tex);
        float4 Tex0 = Tex.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * Delta.xyyy);
        float4 Tex1 = Tex.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * Delta.xyyy);
        float4 Tex2 = Tex.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * Delta.xyyy);

        float4 A0 = tex2D(SampleSource, Tex0.xy);
        float4 A1 = tex2D(SampleSource, Tex0.xz);
        float4 A2 = tex2D(SampleSource, Tex0.xw);

        float4 B0 = tex2D(SampleSource, Tex1.xy);
        float4 B1 = tex2D(SampleSource, Tex1.xz);
        float4 B2 = tex2D(SampleSource, Tex1.xw);

        float4 C0 = tex2D(SampleSource, Tex2.xy);
        float4 C1 = tex2D(SampleSource, Tex2.xz);
        float4 C2 = tex2D(SampleSource, Tex2.xw);

        float3 Weights = float3(1.0, 2.0, 4.0) / 16.0;
        float4 OutputColor = 0.0;
        OutputColor += ((A0 + C0 + A2 + C2) * Weights[0]);
        OutputColor += ((A1 + B0 + C1 + B2) * Weights[1]);
        OutputColor += (B1 * Weights[2]);
        return OutputColor;
    }

    struct CBlur_KarisSample
    {
        float4 Color;
        float Weight;
    };

    float CBlur_GetKarisWeight(float3 c)
    {
        float Brightness = max(max(c.r, c.g), c.b);
        return 1.0 / (Brightness + 1.0);
    }

    CBlur_KarisSample GetKarisSample(sampler2D SamplerSource, float2 Tex)
    {
        CBlur_KarisSample Output;
        Output.Color = tex2D(SamplerSource, Tex);
        Output.Weight = CBlur_GetKarisWeight(Output.Color.rgb);
        return Output;
    }

    float4 CBlur_GetKarisAverage(CBlur_KarisSample Group[4])
    {
        float4 OutputColor = 0.0;
        float WeightSum = 0.0;

        for (int i = 0; i < 4; i++)
        {
            OutputColor += Group[i].Color;
            WeightSum += Group[i].Weight;
        }

        OutputColor.rgb /= WeightSum;

        return OutputColor;
    }

    float4 CBlur_Downsample6x6(sampler2D SampleSource, float2 Tex, bool PartialKaris)
    {
        float4 OutputColor0 = 0.0;

        // A0 -- B0 -- C0
        // -- D0 -- D1 --
        // A1 -- B1 -- C1
        // -- D2 -- D3 --
        // A2 -- B2 -- C2
        float2 Delta = fwidth(Tex);
        float4 Tex0 = Tex.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * Delta.xyxy);
        float4 Tex1 = Tex.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Delta.xyyy);
        float4 Tex2 = Tex.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Delta.xyyy);
        float4 Tex3 = Tex.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Delta.xyyy);

        if (PartialKaris)
        {
            CBlur_KarisSample A0 = GetKarisSample(SampleSource, Tex1.xy);
            CBlur_KarisSample A1 = GetKarisSample(SampleSource, Tex1.xz);
            CBlur_KarisSample A2 = GetKarisSample(SampleSource, Tex1.xw);

            CBlur_KarisSample B0 = GetKarisSample(SampleSource, Tex2.xy);
            CBlur_KarisSample B1 = GetKarisSample(SampleSource, Tex2.xz);
            CBlur_KarisSample B2 = GetKarisSample(SampleSource, Tex2.xw);

            CBlur_KarisSample C0 = GetKarisSample(SampleSource, Tex3.xy);
            CBlur_KarisSample C1 = GetKarisSample(SampleSource, Tex3.xz);
            CBlur_KarisSample C2 = GetKarisSample(SampleSource, Tex3.xw);

            CBlur_KarisSample D0 = GetKarisSample(SampleSource, Tex0.xw);
            CBlur_KarisSample D1 = GetKarisSample(SampleSource, Tex0.zw);
            CBlur_KarisSample D2 = GetKarisSample(SampleSource, Tex0.xy);
            CBlur_KarisSample D3 = GetKarisSample(SampleSource, Tex0.zy);

            CBlur_KarisSample GroupA[4] = { A0, B0, A1, B1 };
            CBlur_KarisSample GroupB[4] = { B0, C0, B1, C1 };
            CBlur_KarisSample GroupC[4] = { A1, B1, A2, B2 };
            CBlur_KarisSample GroupD[4] = { B1, C1, B2, C2 };
            CBlur_KarisSample GroupE[4] = { D0, D1, D2, D3 };

            OutputColor0 += (CBlur_GetKarisAverage(GroupA) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupB) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupC) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupD) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupE) * float2(0.500, 0.500 / 4.0).xxxy);
        }
        else
        {
            float4 A0 = tex2D(SampleSource, Tex1.xy);
            float4 A1 = tex2D(SampleSource, Tex1.xz);
            float4 A2 = tex2D(SampleSource, Tex1.xw);

            float4 B0 = tex2D(SampleSource, Tex2.xy);
            float4 B1 = tex2D(SampleSource, Tex2.xz);
            float4 B2 = tex2D(SampleSource, Tex2.xw);

            float4 C0 = tex2D(SampleSource, Tex3.xy);
            float4 C1 = tex2D(SampleSource, Tex3.xz);
            float4 C2 = tex2D(SampleSource, Tex3.xw);

            float4 D0 = tex2D(SampleSource, Tex0.xw);
            float4 D1 = tex2D(SampleSource, Tex0.zw);
            float4 D2 = tex2D(SampleSource, Tex0.xy);
            float4 D3 = tex2D(SampleSource, Tex0.zy);

            float4 GroupA = A0 + B0 + A1 + B1;
            float4 GroupB = B0 + C0 + B1 + C1;
            float4 GroupC = A1 + B1 + A2 + B2;
            float4 GroupD = B1 + C1 + B2 + C2;
            float4 GroupE = D0 + D1 + D2 + D3;

            OutputColor0 += (GroupA * (0.125 / 4.0));
            OutputColor0 += (GroupB * (0.125 / 4.0));
            OutputColor0 += (GroupC * (0.125 / 4.0));
            OutputColor0 += (GroupD * (0.125 / 4.0));
            OutputColor0 += (GroupE * (0.500 / 4.0));
        }

        return OutputColor0;
    }

    /*
        3x3 Median
        Morgan McGuire and Kyle Whitson
        http://graphics.cs.williams.edu

        Copyright (c) Morgan McGuire and Williams College, 2006
        All rights reserved.

        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are
        met:

        Redistributions of source code must retain the above copyright notice,
        this list of conditions and the following disclaimer.

        Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
        "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
        LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
        A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
        HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
        SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
        LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
        DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
        THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
        (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
        OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    */

    #define CBLUR_MEDIAN_SWAP2(A, B) \
        Temp = A; \
        A = min(A, B); \
        B = max(Temp, B); \

    #define CBLUR_MEDIAN_MN3(A, B, C) \
        CBLUR_MEDIAN_SWAP2(A, B); \
        CBLUR_MEDIAN_SWAP2(A, C); \

    #define CBLUR_MEDIAN_MX3(A, B, C) \
        CBLUR_MEDIAN_SWAP2(B, C); \
        CBLUR_MEDIAN_SWAP2(A, C); \

    // 3 exchanges
    #define CBLUR_MEDIAN_MNMX3(A, B, C) \
        CBLUR_MEDIAN_MX3(A, B, C); \
        CBLUR_MEDIAN_SWAP2(A, B); \

    // 4 exchanges
    #define CBLUR_MEDIAN_MNMX4(A, B, C, D) \
        CBLUR_MEDIAN_SWAP2(A, B); \
        CBLUR_MEDIAN_SWAP2(C, D); \
        CBLUR_MEDIAN_SWAP2(A, C); \
        CBLUR_MEDIAN_SWAP2(B, D); \

    // 6 exchanges
    #define CBLUR_MEDIAN_MNMX5(A, B, C, D, E) \
        CBLUR_MEDIAN_SWAP2(A, B); \
        CBLUR_MEDIAN_SWAP2(C, D); \
        CBLUR_MEDIAN_MN3(A, C, E); \
        CBLUR_MEDIAN_MX3(B, D, E); \

    // 7 exchanges
    #define CBLUR_MEDIAN_MNMX6(A, B, C, D, E, F) \
        CBLUR_MEDIAN_SWAP2(A, D); \
        CBLUR_MEDIAN_SWAP2(B, E); \
        CBLUR_MEDIAN_SWAP2(C, F); \
        CBLUR_MEDIAN_MN3(A, B, C); \
        CBLUR_MEDIAN_MX3(D, E, F); \

    #define TEMPLATE_CBLUR_GETMEDIAN3X3(DATA_TYPE, LENGTH) \
        DATA_TYPE CBlur_GetMedian3x3_FLT##LENGTH(DATA_TYPE InArray[9]) \
        { \
            DATA_TYPE Temp; \
            DATA_TYPE Array[9]; \
            \
            [unroll] \
            for (int i = 0; i < 9; i++) \
            { \
                Array[i] = InArray[i]; \
            } \
            \
            /* Starting with a subset of size 6, remove the min and max each time */ \
            CBLUR_MEDIAN_MNMX6(Array[0], Array[1], Array[2], Array[3], Array[4], Array[5]); \
            CBLUR_MEDIAN_MNMX5(Array[1], Array[2], Array[3], Array[4], Array[6]); \
            CBLUR_MEDIAN_MNMX4(Array[2], Array[3], Array[4], Array[7]); \
            CBLUR_MEDIAN_MNMX3(Array[3], Array[4], Array[8]); \
            return Array[4]; \
        } \

    TEMPLATE_CBLUR_GETMEDIAN3X3(float, 1) // float CBlur_GetMedian3x3FLT(float InArray[9])
    TEMPLATE_CBLUR_GETMEDIAN3X3(float2, 2) // float2 CBlur_GetMedian3x3FLT(float2 InArray[9])
    TEMPLATE_CBLUR_GETMEDIAN3X3(float3, 3) // float3 CBlur_GetMedian3x3FLT(float3 InArray[9])
    TEMPLATE_CBLUR_GETMEDIAN3X3(float4, 4) // float4 CBlur_GetMedian3x3FLT(float4 InArray[9])

    #define TEMPLATE_CBLUR_GETMADGM3x3(DATA_TYPE, LENGTH) \
        float CBlur_GetMADGM3x3_FLT##LENGTH(DATA_TYPE Array[9]) \
        { \
            DATA_TYPE Median = CBlur_GetMedian3x3_FLT##LENGTH(Array); \
            float Distances[9]; \
            /* Create an array of Median Differences */ \
            [unroll] \
            for (int i = 0; i < 9; i++) \
            { \
                Distances[i] = length(Array[i] - Median); \
            } \
            \
            float MADGM = CBlur_GetMedian3x3_FLT1(Distances); \
            float NMADGM = (MADGM > 0.0) ? Distances[4] / MADGM : 0.0; \
            return NMADGM; \
        } \

    TEMPLATE_CBLUR_GETMADGM3x3(float, 1) // float CBlur_GetMADGM3x3_FLT1(float Array[9])
    TEMPLATE_CBLUR_GETMADGM3x3(float2, 2) // float2 CBlur_GetMADGM3x3_FLT2(float2 Array[9])
    TEMPLATE_CBLUR_GETMADGM3x3(float3, 3) // float3 CBlur_GetMADGM3x3_FLT3(float3 Array[9])
    TEMPLATE_CBLUR_GETMADGM3x3(float4, 4) // float4 CBlur_GetMADGM3x3_FLT4(float4 Array[9])

    /*
        This is an optimized, self-guided version for Joint Bilateral Upsampling implemented in HLSL.

        Inspired by Kopf et al. (2007) and Riemens et al. (2009).

        ---

        Kopf, J., Cohen, M. F., Lischinski, D., & Uyttendaele, M. (2007). Joint bilateral upsampling. ACM SIGGRAPH 2007 Papers, 96. https://doi.org/10.1145/1275808.1276497

        Riemens, A. K., Gangwal, O. P., Barenbrug, B., & Berretty, R.-P. M. (2009). Multistep joint bilateral depth upsampling. In M. Rabbani & R. L. Stevenson (Eds.), SPIE Proceedings (Vol. 7257, p. 72570M). SPIE. https://doi.org/10.1117/12.805640

        Yin, H., Gong, Y., & Qiu, G. (2019). Side window filtering. In Proceedings of the IEEE/CVF conference on computer vision and pattern recognition (pp. 8758-8766).
    */

    struct CBlur_SharedData_SideWindow_Bilateral
    {
        // Shared constants
        int ArrayImageLength;
        int SideWindowSize_Corner;
        int SideWindowSize_Cardinal;

        // Shared between side windows
        float2 ArrayImages[9];
        float ArrayDistances[9];
        float2 SideWindowMeans[8];
        float GVariance_Sq;

        // Shared for final calculation
        float2 Reference;
    };

    struct CBlur_SideWindow_Bilateral
    {
        float Masks[9];
        float Size;

        float2 Sum;
        float SumWeight;

        float Influence_Sq;
    };

    void CBlur_GetSharedData_SideWindow_Bilateral(
        sampler Image, // Low-res motion vectors (e.g., 1/2 size)
        sampler Guide, // High-res structural guide (e.g., full size)
        float2 Tex,
        out CBlur_SharedData_SideWindow_Bilateral Output
    )
    {
        const int ArrayImageLength = 9;
        const int SideWindowSize_Corner = 4;
        const int SideWindowSize_Cardinal = 6;

        // Precompute constants (side windows)
        Output.SideWindowSize_Corner = SideWindowSize_Corner;
        Output.SideWindowSize_Cardinal = SideWindowSize_Cardinal;

        // Initialize variables
        Output.ArrayImageLength = ArrayImageLength;
        Output.Reference = tex2D(Guide, Tex).xy;

        // Precompute (static)
        float2 PixelSize = fwidth(Tex.xy);

        /*
            Gather samples:

            0 3 6 [ North West | North  | North East ]
            1 4 7 [    West    | Center |    East    ]
            2 5 8 [ South West | South  | South East ]
        */

        // Initialize counter here
        int ImageIndex0 = 0;

        [unroll]
        for (int x0 = -1; x0 <= 1; x0++)
        {
            [unroll]
            for (int y0 = -1; y0 <= 1; y0++)
            {
                // *2 because the lower sample takes a 2 texel footprint.
                float2 Delta = float2(x0, y0) * 2.0;
                float2 Offset = Tex + (Delta * PixelSize);
                Output.ArrayImages[ImageIndex0] = tex2D(Image, Offset).xy;

                ImageIndex0 += 1;
            }
        }

        /*
            Compute the Coherance.

            Simplication of the factor inside the square root (S):

                1. Tr(M)^2 - 4det(M)
                2. (a + c)^2 - 4(ac - b^2)
                3. a^2 + 2ac + c^2 - 4ac + 4b^2
                4. a^2 - 2ac + c^2 + 4b^2
                5. (a - c)^2 + 4b^2

                1. E = (Tr(M) +- sqrt((a - c)^2 + 4b^2)) / 2
                2. E = (Tr(M) / 2) +- sqrt(((a - c)^2 / 4) + (4b^2 / 4))
                3. E = (Tr(M) / 2) +- sqrt(((a - c) / 2)^2 + b^2)

                E1 = (Tr(M) / 2) + sqrt(((a - c) / 2)^2 + b^2)
                E2 = (Tr(M) / 2) - sqrt(((a - c) / 2)^2 + b^2)

            Now we need to compute C: (E1 - E2) / (E1 + E2)

                E1 - E2:

                    1. ((Tr(M) / 2) + sqrt(((a - c) / 2)^2 + b^2)) - ((Tr(M) / 2) - sqrt(((a - c) / 2)^2 + b^2))
                    2. (Tr(M) / 2) + sqrt(((a - c) / 2)^2 + b^2) - (Tr(M) / 2) + sqrt(((a - c) / 2)^2 + b^2)
                    3. sqrt(((a - c) / 2)^2 + b^2) + sqrt(((a - c) / 2)^2 + b^2)
                    4. 2 * sqrt(((a - c) / 2)^2 + b^2)

                E1 + E2:

                    1. (Tr(M) / 2) + sqrt(((a - c) / 2)^2 + b^2) + ((Tr(M) / 2) - sqrt(((a - c) / 2)^2 + b^2))
                    2. (Tr(M) / 2) + (Tr(M) / 2)
                    3. 2 * (Tr(M) / 2)
                    4. Tr(M)

                Therefore: (2 * sqrt(((a - c) / 2)^2 + b^2)) / Tr(M)
        */

        const float K_H[ArrayImageLength] =
        {
            -1.0 / 4.0, -2.0 / 4.0, -1.0 / 4.0,
             0.0,        0.0,        0.0,
             1.0 / 4.0,  2.0 / 4.0,  1.0 / 4.0
        };

        const float K_V[ArrayImageLength] =
        {
            -1.0 / 4.0, 0.0, 1.0 / 4.0,
            -2.0 / 4.0, 0.0, 2.0 / 4.0,
            -1.0 / 4.0, 0.0, 1.0 / 4.0
        };

        float2 Gx = 0.0;
        float2 Gy = 0.0;

        // Completely unrolled to avoid SM3 loop register index penalties
        [unroll]
        for (int i = 0; i < ArrayImageLength; i++)
        {
            Gx += (Output.ArrayImages[i] * K_H[i]);
            Gy += (Output.ArrayImages[i] * K_V[i]);
        }

        float DotGxGx = dot(Gx, Gx);
        float DotGyGy = dot(Gy, Gy);
        float DotGxGy = dot(Gx, Gy);

        float Trace = (DotGxGx + DotGyGy);          // Element (a + c)
        float Diff  = (DotGxGx - DotGyGy) * 0.5;    // Element (a - c) / 2
        float N = (Diff * Diff) + (DotGxGy * DotGxGy);
        float D = Trace * Trace;

        // Normalized Squared Coherence: 0 (flat), (highly directional edge)
        float Coherence = (D > 0.0) ? (4.0 * N) / D : 0.0;

        // Map into your global variance framework
        Output.GVariance_Sq = Coherence + 1e-7;

        // Reset counter and start again
        int ImageIndex1 = 0;

        [unroll]
        for (int x1 = -1; x1 <= 1; x1++)
        {
            [unroll]
            for (int y1 = -1; y1 <= 1; y1++)
            {
                // Compute shared Weight (Range) here.
                float2 Delta = Output.ArrayImages[ImageIndex1] - Output.Reference;
                float DistRange_Sq = dot(Delta, Delta);
                Output.ArrayDistances[ImageIndex1] = CMath_GetLorentzian1D_Fast(DistRange_Sq, 1.0, Output.GVariance_Sq);

                ImageIndex1 += 1;
            }
        }

        /*
            Construct array of kernels:

            [0] [3] [6]  (Top Row)
            [1] [4] [7]  (Middle Row)
            [2] [5] [8]  (Bottom Row)

            NORTH   SOUTH   EAST    WEST
            x x x   - - -   - x x   x x -
            x x x   x x x   - x x   x x -
            - - -   x x x   - x x   x x -

            NORTHWEST   NORTHEAST   SOUTHWEST   SOUTHEAST
            x x -       - x x       - - -       - - -
            x x -       - x x       x x -       - x x
            - - -       - - -       x x -       - x x
        */

        const float SideWindowWeight_Corner = 1.0 / float(Output.SideWindowSize_Corner);
        const float SideWindowWeight_Cardinal = 1.0 / float(Output.SideWindowSize_Cardinal);

        float2 Submeans[8];
        Submeans[0] = Output.ArrayImages[0].xy + Output.ArrayImages[1].xy; // Vertical Top-Left (V_TL)
        Submeans[1] = Output.ArrayImages[3].xy + Output.ArrayImages[4].xy; // Vertical Top-Mid (V_TM)
        Submeans[2] = Output.ArrayImages[6].xy + Output.ArrayImages[7].xy; // Vertical Top-Right (V_TR)
        Submeans[3] = Output.ArrayImages[1].xy + Output.ArrayImages[2].xy; // Vertical Bottom-Left (V_BL)
        Submeans[4] = Output.ArrayImages[4].xy + Output.ArrayImages[5].xy; // Vertical Bottom-Mid (V_BM)
        Submeans[5] = Output.ArrayImages[7].xy + Output.ArrayImages[8].xy; // Vertical Bottom-Right (V_BR)
        Submeans[6] = Output.ArrayImages[2].xy + Output.ArrayImages[5].xy; // Horizontal Bottom-Left (H_BL)
        Submeans[7] = Output.ArrayImages[5].xy + Output.ArrayImages[8].xy; // Horizontal Bottom-Right (H_BR)

        Output.SideWindowMeans[0] = Submeans[0] + Submeans[1]; // NW: [0 + 1] + [3 + 4]
        Output.SideWindowMeans[1] = Submeans[1] + Submeans[2]; // NE: [3 + 4] + [6 + 7]
        Output.SideWindowMeans[2] = Submeans[3] + Submeans[4]; // SW: [1 + 2] + [4 + 5]
        Output.SideWindowMeans[3] = Submeans[4] + Submeans[5]; // SE: [4 + 5] + [7 + 8]
        Output.SideWindowMeans[4] = Output.SideWindowMeans[0] + Submeans[2]; // N: [0 + 1 + 3 + 4] + [6 + 7]
        Output.SideWindowMeans[5] = Output.SideWindowMeans[2] + Submeans[5]; // S: [1 + 2 + 4 + 5] + [7 + 8]
        Output.SideWindowMeans[6] = Output.SideWindowMeans[0] + Submeans[6]; // W: [0 + 1 + 3 + 4] + [2 + 5]
        Output.SideWindowMeans[7] = Output.SideWindowMeans[1] + Submeans[7]; // E: [3 + 4 + 6 + 7] + [5 + 8]

        Output.SideWindowMeans[0] *= SideWindowWeight_Corner;
        Output.SideWindowMeans[1] *= SideWindowWeight_Corner;
        Output.SideWindowMeans[2] *= SideWindowWeight_Corner;
        Output.SideWindowMeans[3] *= SideWindowWeight_Corner;
        Output.SideWindowMeans[4] *= SideWindowWeight_Cardinal;
        Output.SideWindowMeans[5] *= SideWindowWeight_Cardinal;
        Output.SideWindowMeans[6] *= SideWindowWeight_Cardinal;
        Output.SideWindowMeans[7] *= SideWindowWeight_Cardinal;
    }

    void CBlur_GetSideWindow_Bilateral(
        in CBlur_SharedData_SideWindow_Bilateral Input,
        in float2 Mean,
        inout CBlur_SideWindow_Bilateral Block
    )
    {
        // Pre-compute Spatial distances.
        // .x = Center (0 + 0); .y = Diagonal (1 + 1); .z = Cardinal (0 + 1)
        const float Epsilon = 1e-7;
        const float3 SpatialDistances = exp2(-float3(0.0, 1.0, 2.0));

        // Initialize output members.
        Block.Sum = 0.0;
        Block.SumWeight = 0.0;

        // Initialize Outputs.
        int ImageIndex = 0;

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                if (Block.Masks[ImageIndex] == 1)
                {
                    // Compute Weight (Spatial).
                    int SpatialOffset = abs(x) + abs(y);
                    float WeightSpatial = SpatialDistances[SpatialOffset];

                    // Fetch Weight (Range) and combine.
                    float WeightRange = Input.ArrayDistances[ImageIndex];
                    float Weight = WeightSpatial * WeightRange;

                    // Accumulate.
                    Block.Sum += (Input.ArrayImages[ImageIndex] * Weight);
                    Block.SumWeight += Weight;
                }

                ImageIndex += 1;
            }
        }

        /*
            Compute the SideWindow's Sample Coefficient of Variance (CoV).

            We use Van Valen's Multivariate Coefficient of Variation because of the computational simplicity.

            Tr = The Trace
            M = The Mean
        */

        // Constant: Sample Variance (Sigma)
        const float SigmaN = 1.0 / (float(Block.Size) - 1.0);

        /*
            We will compute the trace of the covariance matrix with vector MADs.

            | xx xy | <- We skip the xy/yx calculation of the matrix.
            | yx yy |
        */

        float2 SigmaVec = 0.0;

        [unroll]
        for (int i1 = 0; i1 < Input.ArrayImageLength; i1++)
        {
            if (Block.Masks[i1] == 1)
            {
                float2 D = Input.ArrayImages[i1] - Mean;
                SigmaVec += (D * D);
            }
        }

        // Compute the Trace (T): (xx / N) + (yy / N).
        float Tr = dot(SigmaVec, SigmaN);

        // Compute the Mean's Squared Euclidian Distance: M^T*M
        float M = dot(Mean, Mean);

        // Coefficient of Variance.
        // We removed the sqrt(x) because the result gets cancelled-out in CMath_GetLorentzian1D_Fast(x)
        float CoV_Sq = (abs(M) > 0.0) ? Tr / M : 0.0;

        // Fit the CoV into a Lorentzian approximation.
        Block.Influence_Sq = CoV_Sq;
    }

    float2 CBlur_GetSelfBilateralUpsample_FLT2(
        sampler Image, // Low-res motion vectors (e.g., 1/2 size)
        sampler Guide, // High-res structural guide (e.g., full size)
        float2 Tex
    )
    {
        const int SideWindowsCount = 8;

        // Create the data struct that we will use accross multiple functions.
        CBlur_SharedData_SideWindow_Bilateral SharedData;
        CBlur_GetSharedData_SideWindow_Bilateral(Image, Guide, Tex, SharedData);

        /*
            Construct array of Masks:

            [0] [3] [6]  (Top Row)
            [1] [4] [7]  (Middle Row)
            [2] [5] [8]  (Bottom Row)

            NORTH   SOUTH   EAST    WEST
            x x x   - - -   - x x   x x -
            x x x   x x x   - x x   x x -
            - - -   x x x   - x x   x x -

            NORTHWEST   NORTHEAST   SOUTHWEST   SOUTHEAST
            x x -       - x x       - - -       - - -
            x x -       - x x       x x -       - x x
            - - -       - - -       x x -       - x x
        */

        // Initialize our side windows
        CBlur_SideWindow_Bilateral SideWindows[SideWindowsCount];
        SideWindows[0].Masks = { 1, 1, 0, 1, 1, 0, 0, 0, 0 }; // NW
        SideWindows[0].Size = SharedData.SideWindowSize_Corner;
        SideWindows[1].Masks = { 0, 0, 0, 1, 1, 0, 1, 1, 0 }; // NE
        SideWindows[1].Size = SharedData.SideWindowSize_Corner;
        SideWindows[2].Masks = { 0, 1, 1, 0, 1, 1, 0, 0, 0 }; // SW
        SideWindows[2].Size = SharedData.SideWindowSize_Corner;
        SideWindows[3].Masks = { 0, 0, 0, 0, 1, 1, 0, 1, 1 }; // SE
        SideWindows[3].Size = SharedData.SideWindowSize_Corner;
        SideWindows[4].Masks = { 1, 1, 0, 1, 1, 0, 1, 1, 0 }; // N
        SideWindows[4].Size = SharedData.SideWindowSize_Cardinal;
        SideWindows[5].Masks = { 0, 1, 1, 0, 1, 1, 0, 1, 1 }; // S
        SideWindows[5].Size = SharedData.SideWindowSize_Cardinal;
        SideWindows[6].Masks = { 1, 1, 1, 1, 1, 1, 0, 0, 0 }; // W
        SideWindows[6].Size = SharedData.SideWindowSize_Cardinal;
        SideWindows[7].Masks = { 0, 0, 0, 1, 1, 1, 1, 1, 1 }; // E
        SideWindows[7].Size = SharedData.SideWindowSize_Cardinal;

        /*
            Calculate the variance-weighted Side Window filter. This may sound strange, but it works better than the regular min(x) method.

            While Google's enterprise-class clanker suggested this method, I did my discernment and revised it to work like do CBloom's Karis averaging. In layman's terms, a Karis average means "we will add 4 things together: darken the very-bright things and keep the not-very-bright-things the same". The "thing" is either a single pixel (for a Full Karis Average) or a sum of pixels (for a Partial Karis Average). We use the Karis average to prevent pulsating regions when downsampling.

            What about motion vectors? Instead of measuring the sum of pixel brightness to infer pulsating areas, we use the sum of pixel variances.
        */

        float2 WindowMean = 0.0;
        float SumInfluence_Sq = 0.0;

        [unroll]
        for (int i0 = 0; i0 < SideWindowsCount; i0++)
        {
            CBlur_GetSideWindow_Bilateral(SharedData, SharedData.SideWindowMeans[i0], SideWindows[i0]);
            if (SideWindows[i0].SumWeight > 0.0)
            {
                // Normalize the sum.
                float2 Sum = SideWindows[i0].Sum / SideWindows[i0].SumWeight;

                // Weighted sum by influence.
                WindowMean += (Sum * SideWindows[i0].Influence_Sq);
                SumInfluence_Sq += SideWindows[i0].Influence_Sq;
            }
        }

        WindowMean = (SumInfluence_Sq > 0.0) ? WindowMean / SumInfluence_Sq : SharedData.SideWindowMeans[4];

        return WindowMean;
    }

    float2 CBlur_GetSideWindowBox_FLT2(sampler2D Image, float2 Tex)
    {
        // Precompute constants (image array)
        const int SideWindowsCount = 8;
        const int ArrayImagesLength = 9;

        // Precompute constants (side windows)
        const int SideWindowSizeCorner = 4;
        const int SideWindowSizeCardinal = 6;
        const float WeightsCorner = 1.0 / float(SideWindowSizeCorner);
        const float WeightsCardinal = 1.0 / float(SideWindowSizeCardinal);

        // Precompute (static)
        float2 PixelSize = fwidth(Tex.xy);
        float2 ArrayImages[ArrayImagesLength];
        float2 Reference;

        /*
            Gather samples:

            0 1 2 [ North West | North  | North East ]
            3 4 5 [    West    | Center |    East    ]
            6 7 8 [ South West | South  | South East ]
        */

        int ImageIndex = 0;

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                // *2 because the lower sample takes a 2 texel footprint.
                float2 Delta = float2(x, y) * 2.0;
                float2 Offset = Tex + (Delta * PixelSize);
                float2 Sample = tex2D(Image, Offset).xy;
                ArrayImages[ImageIndex] = Sample;

                if ((x == 0) && (y == 0))
                {
                    Reference = ArrayImages[ImageIndex];
                }

                ImageIndex += 1;
            }
        }

        /*
            [0] [1] [2]  (Top Row)
            [3] [4] [5]  (Mid Row)
            [6] [7] [8]  (Bot Row)

            Construct array of kernels:

            NORTH   SOUTH   EAST    WEST
            x x x   - - -   - x x   x x -
            x x x   x x x   - x x   x x -
            - - -   x x x   - x x   x x -

            NORTHWEST   NORTHEAST   SOUTHWEST   SOUTHEAST
            x x -       - x x       - - -       - - -
            x x -       - x x       x x -       - x x
            - - -       - - -       x x -       - x x
        */

        float2 Submeans[8];
        Submeans[0] = ArrayImages[0] + ArrayImages[3]; // Vertical-Top-Left
        Submeans[1] = ArrayImages[1] + ArrayImages[4]; // Vertical-Top-Mid
        Submeans[2] = ArrayImages[2] + ArrayImages[5]; // Vertical-Top-Right
        Submeans[3] = ArrayImages[3] + ArrayImages[6]; // Vertical-Bottom-Left
        Submeans[4] = ArrayImages[4] + ArrayImages[7]; // Vertical-Bottom-Mid
        Submeans[5] = ArrayImages[5] + ArrayImages[8]; // Vertical-Bottom-Right
        Submeans[6] = ArrayImages[6] + ArrayImages[7]; // Horizontal-Bottom-Left
        Submeans[7] = ArrayImages[7] + ArrayImages[8]; // Horizontal-Bottom-Right

        float2 Means[8];
        Means[0] = Submeans[0] + Submeans[1]; // NW: [0 + 3] + [1 + 4]
        Means[1] = Submeans[1] + Submeans[2]; // NE: [1 + 4] + [2 + 5]
        Means[2] = Submeans[3] + Submeans[4]; // SW: [3 + 6] + [4 + 7]
        Means[3] = Submeans[4] + Submeans[5]; // SE: [4 + 7] + [5 + 8]
        Means[4] = Means[0] + Submeans[2]; // N: [0 + 3 + 1 + 4] + [2 + 5]
        Means[5] = Means[2] + Submeans[5]; // S: [3 + 6 + 4 + 7] + [5 + 8]
        Means[6] = Means[0] + Submeans[6]; // W: [0 + 3 + 1 + 4] + [6 + 7]
        Means[7] = Means[1] + Submeans[7]; // E: [1 + 4 + 2 + 5] + [7 + 8]

        Means[0] *= WeightsCorner;
        Means[1] *= WeightsCorner;
        Means[2] *= WeightsCorner;
        Means[3] *= WeightsCorner;
        Means[4] *= WeightsCardinal;
        Means[5] *= WeightsCardinal;
        Means[6] *= WeightsCardinal;
        Means[7] *= WeightsCardinal;

        // Calculate Side Winder filter
        float2 NearestWindow = Reference;
        bool AError = false;
        float Error = 0.0;

        [unroll]
        for (int i0 = 0; i0 < SideWindowsCount; i0++)
        {
            float2 Delta = Means[i0] - Reference;
            float WindowError = dot(Delta, Delta);

            if (!AError || (WindowError < Error))
            {
                AError = true;
                Error = WindowError;
                NearestWindow = Means[i0];
            }
        }

        return NearestWindow;
    }

    // Initialize variables to compute
    float4 CBlur_GetJointBilateralUpsample(
        sampler Image, // This should be 1/2 the size as GuideHigh
        sampler GuideLow, // This should be 1/2 the size as GuideHigh
        sampler GuideHigh, // This should be 2/1 the size as Image and GuideLow
        float2 Tex
    )
    {
        // Initialize variables
        float2 PixelSize = ldexp(fwidth(Tex.xy), 1.0);
        float4 GuideHighSample = tex2D(GuideHigh, Tex);

        float4 BilateralSum = 0.0;
        float BilateralWeightSum = 0.0;

        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            [unroll]
            for (int y = -1; y <= 1; y++)
            {
                // Calculate offset
                float2 Offset = float2(x, y);
                float2 OffsetTex = Tex + (Offset * PixelSize);

                // Sample image and guide
                float4 ImageSample = tex2D(Image, OffsetTex);
                float4 GuideLowSample = tex2D(GuideLow, OffsetTex);

                // Calculate weight
                float4 D = GuideHighSample - GuideLowSample;
                float2 DotDD = float2(dot(D.xy, D.xy), dot(D.zw, D.zw));
                float2 Weights = smoothstep(0.0, 1.0, rsqrt(DotDD + 1.0));
                float Weight = rsqrt(dot(Offset, Offset) + 1.0);
                Weight *= Weights[0] * Weights[1];

                // Accumulate bilateral
                BilateralSum += (ImageSample * Weight);
                BilateralWeightSum += Weight;
            }
        }

        BilateralSum = BilateralSum / BilateralWeightSum;

        return BilateralSum;
    }

#endif
