
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

    float CBlur_GetGaussianWeight1D(float X, float S)
    {
        float G = rsqrt(2.0 * CMath_GetPi() * S * S);
        return G * exp(-(X * X) / (2.0 * S * S));
    }

    float CBlur_GetGaussianWeight2D(float2 X, float S)
    {
        float G = 1.0 / (2.0 * CMath_GetPi() * S * S);
        return G * exp(-dot(X, X) / (2.0 * S * S));
    }

    float CBlur_GetGaussianOffset(float SampleIndex, float Sigma, out float LinearWeight)
    {
        float Offset1 = SampleIndex;
        float Offset2 = SampleIndex + 1.0;
        float Weight1 = CBlur_GetGaussianWeight1D(Offset1, Sigma);
        float Weight2 = CBlur_GetGaussianWeight1D(Offset2, Sigma);
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

    void Swap2(inout float4 A, inout float4 B)
    {
        float4 Temp = A;
        A = min(A, B);
        B = max(Temp, B);
    }

    void MN3(inout float4 A, inout float4 B, inout float4 C)
    {
        Swap2(A, B);
        Swap2(A, C);
    }

    void MX3(inout float4 A, inout float4 B, inout float4 C)
    {
        Swap2(B, C);
        Swap2(A, C);
    }

    // 3 exchanges
    void MNMX3(inout float4 A, inout float4 B, inout float4 C)
    {
        MX3(A, B, C);
        Swap2(A, B);
    }

    // 4 exchanges
    void MNMX4(inout float4 A, inout float4 B, inout float4 C, inout float4 D)
    {
        Swap2(A, B);
        Swap2(C, D);
        Swap2(A, C);
        Swap2(B, D);
    }

    // 6 exchanges
    void MNMX5(inout float4 A, inout float4 B, inout float4 C, inout float4 D, inout float4 E)
    {
        Swap2(A, B);
        Swap2(C, D);
        MN3(A, C, E);
        MX3(B, D, E);
    }

    // 7 exchanges
    void MNMX6(inout float4 A, inout float4 B, inout float4 C, inout float4 D, inout float4 E, inout float4 F)
    {
        Swap2(A, D);
        Swap2(B, E);
        Swap2(C, F);
        MN3(A, B, C);
        MX3(D, E, F);
    }

    float4 CBlur_GetMedian(sampler Source, float2 Tex)
    {
        float2 PixelSize = fwidth(Tex.xy);

        // Add the pixels which make up our window to the pixel array.
        float4 Array[9];

        [unroll]
        for (int dx = -1; dx <= 1; ++dx)
        {
            [unroll]
            for (int dy = -1; dy <= 1; ++dy)
            {
                float2 Offset = float2(float(dx), float(dy));

                // If a pixel in the window is located at (x+dx, y+dy), put it at index (dx + R)(2R + 1) + (dy + R) of the
                // pixel array. This will fill the pixel array, with the top left pixel of the window at pixel[0] and the
                // bottom right pixel of the window at pixel[N-1].
                int ID = (dx + 1) * 3 + (dy + 1);
                Array[ID] = tex2D(Source, Tex + (Offset * PixelSize));
            }
        }

        // Starting with a subset of size 6, remove the min and max each time
        MNMX6(Array[0], Array[1], Array[2], Array[3], Array[4], Array[5]);
        MNMX5(Array[1], Array[2], Array[3], Array[4], Array[6]);
        MNMX4(Array[2], Array[3], Array[4], Array[7]);
        MNMX3(Array[3], Array[4], Array[8]);

        return Array[4];
    }

    /*
        This is an optimized, self-guided version for Joint Bilateral Upsampling implemented in HLSL.

        Inspired by Kopf et al. (2007) and Riemens et al. (2009).

        ---

        Kopf, J., Cohen, M. F., Lischinski, D., & Uyttendaele, M. (2007). Joint bilateral upsampling. ACM SIGGRAPH 2007 Papers, 96. https://doi.org/10.1145/1275808.1276497

        Riemens, A. K., Gangwal, O. P., Barenbrug, B., & Berretty, R.-P. M. (2009). Multistep joint bilateral depth upsampling. In M. Rabbani & R. L. Stevenson (Eds.), SPIE Proceedings (Vol. 7257, p. 72570M). SPIE. https://doi.org/10.1117/12.805640

        Yin, H., Gong, Y., & Qiu, G. (2019). Side window filtering. In Proceedings of the IEEE/CVF conference on computer vision and pattern recognition (pp. 8758-8766).
    */

    struct CBlur_SideWindowBlockBilateral
    {
        float2 Mean;
        float Variance;
        int Weights[9];
    };

    struct CBlur_SideWindowBilateral
    {
        float2 Sum;
        float SumWeight;
    };

    void CBlur_InitSideWindowBilateral(
        in int SubwindowSize,
        in float3 ImageArray[9],
        in float2 Mean,
        inout CBlur_SideWindowBlockBilateral Block)
    {
        const int ImageArraySize = 9;
        const float MeanN = 1.0 / float(SubwindowSize);
        const float VarianceN = 1.0 / (float(SubwindowSize) - 1.0);

        // Compute Mean
        Block.Mean = Mean * MeanN;

        // Initialize variance data
        Block.Variance = 0.0;

        [unroll]
        for (int i1 = 0; i1 < ImageArraySize; i1++)
        {
            if (Block.Weights[i1] == 1)
            {
                float2 D = ImageArray[i1].xy - Block.Mean;
                Block.Variance += (dot(D, D) * VarianceN);
            }
        }
    }

    void CBlur_GetSideWindowBilateral(
        in float3 ImageArray[9],
        in CBlur_SideWindowBlockBilateral Block,
        out CBlur_SideWindowBilateral Output
    )
    {
        // Initialize output data
        int ImageIndex = 0;

        // Initialize Outputs
        float VarD = 1.0 + Block.Variance;
        float2 Sum = 0.0;
        float WSum = 0.0;

        // Pre-compute Spatial distances
        // .x = Center (0 + 0); .y = Diagonal (1 + 1); .z = Cardinal (0 + 1)
        float3 SpatialDistances = exp2(-float3(0.0, 1.0, 2.0));

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                if (Block.Weights[ImageIndex] == 1)
                {
                    // Compute Weight (Range)
                    float DistSqRange = ImageArray[ImageIndex].z;
                    float WeightRange = 1.0 / (DistSqRange + VarD);

                    // Compute Weight (Spatial)
                    int SpatialOffset = abs(x) + abs(y);
                    float WeightSpatial = SpatialDistances[SpatialOffset];
                    float Weight = WeightSpatial * WeightRange;

                    // Accumulate
                    Sum += (ImageArray[ImageIndex].xy * Weight);
                    WSum += Weight;
                }

                ImageIndex += 1;
            }
        }

        Output.Sum = Sum;
        Output.SumWeight = WSum;
    }

    float2 CBlur_GetSelfBilateralUpsampleXY(
        sampler Image, // Low-res motion vectors (e.g., 1/2 size)
        sampler Guide, // High-res structural guide (e.g., full size)
        float2 Tex
    )
    {
        // Precompute (constants)
        const int ArrayCount = 9;

        // Precompute (static)
        float2 PixelSize = ldexp(fwidth(Tex.xy), 1.0);
        float2 GuideTexture = tex2D(Guide, Tex).xy;
        float2 Reference;

        float3 ImageArray[ArrayCount];
        int ImageIndex = 0;

        /*
            Gather samples:

            0 1 2 [ North West | North  | North East ]
            3 4 5 [    West    | Center |    East    ]
            6 7 8 [ South West | South  | South East ]
        */

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                float2 Offset = Tex + (float2(x, y) * PixelSize);
                float2 Sample = tex2D(Image, Offset).xy;
                float2 Delta = Sample - GuideTexture;
                ImageArray[ImageIndex].xy = Sample;
                ImageArray[ImageIndex].z = dot(Delta, Delta);

                if ((x == 0) && (y == 0))
                {
                    Reference = ImageArray[ImageIndex].xy;
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

        float2 Submean[8];
        Submean[0] = ImageArray[0].xy + ImageArray[3].xy; // Vertical-Top-Left
        Submean[1] = ImageArray[1].xy + ImageArray[4].xy; // Vertical-Top-Mid
        Submean[2] = ImageArray[2].xy + ImageArray[5].xy; // Vertical-Top-Right
        Submean[3] = ImageArray[3].xy + ImageArray[6].xy; // Vertical-Bottom-Left
        Submean[4] = ImageArray[4].xy + ImageArray[7].xy; // Vertical-Bottom-Mid
        Submean[5] = ImageArray[5].xy + ImageArray[8].xy; // Vertical-Bottom-Right
        Submean[6] = ImageArray[6].xy + ImageArray[7].xy; // Horizontal-Bottom-Left
        Submean[7] = ImageArray[7].xy + ImageArray[8].xy; // Horizontal-Bottom-Right

        float2 Mean[8];
        Mean[0] = Submean[0] + Submean[1]; // NW (0+3 + 1+4)
        Mean[1] = Submean[1] + Submean[2]; // NE (1+4 + 2+5)
        Mean[2] = Submean[3] + Submean[4]; // SW (3+6 + 4+7)
        Mean[3] = Submean[4] + Submean[5]; // SE (4+7 + 5+8)
        Mean[4] = Mean[0] + Submean[2]; // N (0+3+1+4 + 2+5)
        Mean[5] = Mean[2] + Submean[5]; // S (3+6+4+7 + 5+8)
        Mean[6] = Mean[0] + Submean[6]; // W (0+3+1+4 + 6+7)
        Mean[7] = Mean[1] + Submean[7]; // E (1+4+2+5 + 7+8)

        const int WindowAmount = 8;
        const int SubwindowSizes[WindowAmount] = { 4, 4, 4, 4, 6, 6, 6, 6 };
        const int StaticWeightsLength = 9;
        const int StaticWeights[StaticWeightsLength * WindowAmount] =
        {
            1, 1, 0,  1, 1, 0,  0, 0, 0, // NW (0-8)
            0, 1, 1,  0, 1, 1,  0, 0, 0, // NE (9-17)
            0, 0, 0,  1, 1, 0,  1, 1, 0, // SW (18-26)
            0, 0, 0,  0, 1, 1,  0, 1, 1, // SE (27-35)
            1, 1, 1,  1, 1, 1,  0, 0, 0, // N  (36-44)
            0, 0, 0,  1, 1, 1,  1, 1, 1, // S  (45-53)
            1, 1, 0,  1, 1, 0,  1, 1, 0, // W  (54-62)
            0, 1, 1,  0, 1, 1,  0, 1, 1  // E  (63-71)
        };

        // Initialize our side windows
        CBlur_SideWindowBlockBilateral Blocks[8];

        [unroll]
        for (int i0 = 0; i0 < 8; i0++)
        {
            [unroll]
            for (int i1 = 0; i1 < StaticWeightsLength; i1++)
            {
                int ID = (i0 * StaticWeightsLength) + i1;
                Blocks[i0].Weights[i1] = StaticWeights[ID];
            }

            CBlur_InitSideWindowBilateral(SubwindowSizes[i0], ImageArray, Mean[i0], Blocks[i0]);
        }

        // Calculate Side Winder filter
        float2 NearestWindow = Reference;
        bool AVariance = false;
        float Variance = 0.0;

        [unroll]
        for (int i2 = 0; i2 < 8; i2++)
        {
            CBlur_SideWindowBilateral SideWindow;
            CBlur_GetSideWindowBilateral(ImageArray, Blocks[i2], SideWindow);

            if (SideWindow.SumWeight > 0.0)
            {
                if (!AVariance || (Blocks[i2].Variance < Variance))
                {
                    AVariance = true;
                    Variance = Blocks[i2].Variance;
                    NearestWindow = SideWindow.Sum / SideWindow.SumWeight;
                }
            }
        }

        return NearestWindow;
    }

    struct CBlur_SideWindowBlockBox
    {
        float2 Mean;
        int Weights[9];
    };

   void CBlur_InitSideWindowBox(
        in int SubwindowSize,
        in float2 Mean,
        inout CBlur_SideWindowBlockBox Block)
    {
        const int ImageArraySize = 9;
        const float MeanN = 1.0 / float(SubwindowSize);

        // Compute Mean
        Block.Mean = Mean * MeanN;
    }

    float2 CBlur_GetSideWindowBoxXY(sampler2D Image, float2 Tex)
    {
        // Precompute (constants)
        const int ArrayCount = 9;

        // Precompute (static)
        float2 PixelSize = ldexp(fwidth(Tex.xy), 1.0);
        float2 Reference;

        float2 ImageArray[ArrayCount];
        int ImageIndex = 0;

        /*
            Gather samples:

            0 1 2 [ North West | North  | North East ]
            3 4 5 [    West    | Center |    East    ]
            6 7 8 [ South West | South  | South East ]
        */

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                float2 Offset = Tex + (float2(x, y) * PixelSize);
                float2 Sample = tex2D(Image, Offset).xy;
                ImageArray[ImageIndex] = Sample;

                if ((x == 0) && (y == 0))
                {
                    Reference = ImageArray[ImageIndex];
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

        float2 Submean[8];
        Submean[0] = ImageArray[0] + ImageArray[3]; // Vertical-Top-Left
        Submean[1] = ImageArray[1] + ImageArray[4]; // Vertical-Top-Mid
        Submean[2] = ImageArray[2] + ImageArray[5]; // Vertical-Top-Right
        Submean[3] = ImageArray[3] + ImageArray[6]; // Vertical-Bottom-Left
        Submean[4] = ImageArray[4] + ImageArray[7]; // Vertical-Bottom-Mid
        Submean[5] = ImageArray[5] + ImageArray[8]; // Vertical-Bottom-Right
        Submean[6] = ImageArray[6] + ImageArray[7]; // Horizontal-Bottom-Left
        Submean[7] = ImageArray[7] + ImageArray[8]; // Horizontal-Bottom-Right

        float2 Mean[8];
        Mean[0] = Submean[0] + Submean[1]; // NW (0+3 + 1+4)
        Mean[1] = Submean[1] + Submean[2]; // NE (1+4 + 2+5)
        Mean[2] = Submean[3] + Submean[4]; // SW (3+6 + 4+7)
        Mean[3] = Submean[4] + Submean[5]; // SE (4+7 + 5+8)
        Mean[4] = Mean[0] + Submean[2]; // N (0+3+1+4 + 2+5)
        Mean[5] = Mean[2] + Submean[5]; // S (3+6+4+7 + 5+8)
        Mean[6] = Mean[0] + Submean[6]; // W (0+3+1+4 + 6+7)
        Mean[7] = Mean[1] + Submean[7]; // E (1+4+2+5 + 7+8)

        const int WindowAmount = 8;
        const int SubwindowSizes[WindowAmount] = { 4, 4, 4, 4, 6, 6, 6, 6 };
        const int StaticWeightsLength = 9;
        const int StaticWeights[StaticWeightsLength * WindowAmount] =
        {
            1, 1, 0,  1, 1, 0,  0, 0, 0, // NW (0-8)
            0, 1, 1,  0, 1, 1,  0, 0, 0, // NE (9-17)
            0, 0, 0,  1, 1, 0,  1, 1, 0, // SW (18-26)
            0, 0, 0,  0, 1, 1,  0, 1, 1, // SE (27-35)
            1, 1, 1,  1, 1, 1,  0, 0, 0, // N  (36-44)
            0, 0, 0,  1, 1, 1,  1, 1, 1, // S  (45-53)
            1, 1, 0,  1, 1, 0,  1, 1, 0, // W  (54-62)
            0, 1, 1,  0, 1, 1,  0, 1, 1  // E  (63-71)
        };

        // Initialize our side windows
        CBlur_SideWindowBlockBox Blocks[8];

        [unroll]
        for (int i0 = 0; i0 < 8; i0++)
        {
            [unroll]
            for (int i1 = 0; i1 < StaticWeightsLength; i1++)
            {
                int ID = (i0 * StaticWeightsLength) + i1;
                Blocks[i0].Weights[i1] = StaticWeights[ID];
            }

            CBlur_InitSideWindowBox(SubwindowSizes[i0], Mean[i0], Blocks[i0]);
        }

        // Calculate Side Winder filter
        float2 NearestWindow = Reference;
        bool AVariance = false;
        float Variance = 0.0;

        [unroll]
        for (int i2 = 0; i2 < 8; i2++)
        {
            float2 Delta = Blocks[i2].Mean - Reference;
            float WindowVariance = dot(Delta, Delta);

            if (!AVariance || (WindowVariance < Variance))
            {
                AVariance = true;
                Variance = WindowVariance;
                NearestWindow = Blocks[i2].Mean;
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
