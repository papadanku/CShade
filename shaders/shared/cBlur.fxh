
#include "cMath.fxh"
#include "cProcedural.fxh"

#if !defined(INCLUDE_CBLUR)
    #define INCLUDE_CBLUR

    /*
        Linear Gaussian blur
        ---
        https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/
    */

    float CBlur_GetGaussianWeight(float SampleIndex, float Sigma)
    {
        float Output = rsqrt(2.0 * CMath_GetPi() * (Sigma * Sigma));
        return Output * exp(-(SampleIndex * SampleIndex) / (2.0 * Sigma * Sigma));
    }

    float CBlur_GetGaussianOffset(float SampleIndex, float Sigma, out float LinearWeight)
    {
        float Offset1 = SampleIndex;
        float Offset2 = SampleIndex + 1.0;
        float Weight1 = CBlur_GetGaussianWeight(Offset1, Sigma);
        float Weight2 = CBlur_GetGaussianWeight(Offset2, Sigma);
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
        for(int i = 1; i < KernelSize; i++)
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

    float4 PS_Bilateral(sampler Source, float2 Tex)
    {
        // Get constant
        const float Pi2 = CMath_GetPi() * 2.0;

        // Initialize variables we need to accumulate samples and calculate offsets
        float4 OutputColor = 0.0;

        // Offset and weighting attributes
        float2 PixelSize = fwidth(Tex);

        // Get bilateral filter
        float4 TotalWeight = 0.0;
        float4 Center = tex2D(Source, Tex);
        [unroll]
        for(int i = 1; i < 4; ++i)
        {
            [unroll]
            for(int j = 0; j < 4 * i; ++j)
            {
                float2 Shift = (Pi2 / (4.0 * float(i))) * float(j);
                sincos(Shift, Shift.x, Shift.y);
                Shift *= float(i);

                float4 Pixel = tex2D(Source, Tex + (Shift * PixelSize));
                float4 Weight = abs(1.0 - abs(Pixel - Center));
                OutputColor += (Pixel * Weight);
                TotalWeight += Weight;
            }
        }

        return OutputColor / TotalWeight;
    }

    /*
        Wojciech Sterna's shadow sampling code as a screen-space convolution (http://maxest.gct-game.net/content/chss.pdf)
        ---
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
            CBlur_KarisSample D0 = GetKarisSample(SampleSource, Tex0.xw);
            CBlur_KarisSample D1 = GetKarisSample(SampleSource, Tex0.zw);
            CBlur_KarisSample D2 = GetKarisSample(SampleSource, Tex0.xy);
            CBlur_KarisSample D3 = GetKarisSample(SampleSource, Tex0.zy);

            CBlur_KarisSample A0 = GetKarisSample(SampleSource, Tex1.xy);
            CBlur_KarisSample A1 = GetKarisSample(SampleSource, Tex1.xz);
            CBlur_KarisSample A2 = GetKarisSample(SampleSource, Tex1.xw);

            CBlur_KarisSample B0 = GetKarisSample(SampleSource, Tex2.xy);
            CBlur_KarisSample B1 = GetKarisSample(SampleSource, Tex2.xz);
            CBlur_KarisSample B2 = GetKarisSample(SampleSource, Tex2.xw);

            CBlur_KarisSample C0 = GetKarisSample(SampleSource, Tex3.xy);
            CBlur_KarisSample C1 = GetKarisSample(SampleSource, Tex3.xz);
            CBlur_KarisSample C2 = GetKarisSample(SampleSource, Tex3.xw);

            CBlur_KarisSample GroupA[4] = { D0, D1, D2, D3 };
            CBlur_KarisSample GroupB[4] = { A0, B0, A1, B1 };
            CBlur_KarisSample GroupC[4] = { B0, C0, B1, C1 };
            CBlur_KarisSample GroupD[4] = { A1, B1, A2, B2 };
            CBlur_KarisSample GroupE[4] = { B1, C1, B2, C2 };

            OutputColor0 += (CBlur_GetKarisAverage(GroupA) * float2(0.500, 0.500 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupB) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupC) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupD) * float2(0.125, 0.125 / 4.0).xxxy);
            OutputColor0 += (CBlur_GetKarisAverage(GroupE) * float2(0.125, 0.125 / 4.0).xxxy);
        }
        else
        {
            float4 D0 = tex2D(SampleSource, Tex0.xw);
            float4 D1 = tex2D(SampleSource, Tex0.zw);
            float4 D2 = tex2D(SampleSource, Tex0.xy);
            float4 D3 = tex2D(SampleSource, Tex0.zy);

            float4 A0 = tex2D(SampleSource, Tex1.xy);
            float4 A1 = tex2D(SampleSource, Tex1.xz);
            float4 A2 = tex2D(SampleSource, Tex1.xw);

            float4 B0 = tex2D(SampleSource, Tex2.xy);
            float4 B1 = tex2D(SampleSource, Tex2.xz);
            float4 B2 = tex2D(SampleSource, Tex2.xw);

            float4 C0 = tex2D(SampleSource, Tex3.xy);
            float4 C1 = tex2D(SampleSource, Tex3.xz);
            float4 C2 = tex2D(SampleSource, Tex3.xw);

            float4 GroupA = D0 + D1 + D2 + D3;
            float4 GroupB = A0 + B0 + A1 + B1;
            float4 GroupC = B0 + C0 + B1 + C1;
            float4 GroupD = A1 + B1 + A2 + B2;
            float4 GroupE = B1 + C1 + B2 + C2;

            OutputColor0 += (GroupA * (0.500 / 4.0));
            OutputColor0 += (GroupB * (0.125 / 4.0));
            OutputColor0 += (GroupC * (0.125 / 4.0));
            OutputColor0 += (GroupD * (0.125 / 4.0));
            OutputColor0 += (GroupE * (0.125 / 4.0));
        }

        return OutputColor0;
    }


    float4 CBlur_GetMedian(sampler Source, float2 Tex, float Scale)
    {
        float2 PixelSize = fwidth(Tex.xy);

        float Angle = radians(45.0);
        float2x2 Rotation = float2x2(cos(Angle), -sin(Angle), sin(Angle), cos(Angle));

        float4 Offsets1 = float4(mul(float2(1.0, 1.0), Rotation), mul(float2(-1.0, -1.0), Rotation));
        float4 Offsets2 = float4(mul(float2(-1.0, 1.0), Rotation), mul(float2(1.0, -1.0), Rotation));
        float4 Offsets3 = float4(mul(float2(0.0, 1.0), Rotation), mul(float2(0.0, -1.0), Rotation));
        float4 Offsets4 = float4(mul(float2(-1.0, 0.0), Rotation), mul(float2(1.0, 0.0), Rotation));
        float4 Tex1 = Tex.xyxy + (ldexp(Offsets1, Scale) * PixelSize.xyxy);
        float4 Tex2 = Tex.xyxy + (ldexp(Offsets2, Scale) * PixelSize.xyxy);
        float4 Tex3 = Tex.xyxy + (ldexp(Offsets3, Scale) * PixelSize.xyxy);
        float4 Tex4 = Tex.xyxy + (ldexp(Offsets4, Scale) * PixelSize.xyxy);

        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        float4 Sample[9];
        Sample[0] = tex2D(Source, Tex1.xy);
        Sample[1] = tex2D(Source, Tex1.zw);
        Sample[2] = tex2D(Source, Tex2.xy);
        Sample[3] = tex2D(Source, Tex2.zw);
        Sample[4] = tex2D(Source, Tex);
        Sample[5] = tex2D(Source, Tex3.xy);
        Sample[6] = tex2D(Source, Tex3.zw);
        Sample[7] = tex2D(Source, Tex4.xy);
        Sample[8] = tex2D(Source, Tex4.zw);
        return CMath_Float4_Med9(
            Sample[0], Sample[1], Sample[2],
            Sample[3], Sample[4], Sample[5],
            Sample[6], Sample[7], Sample[8]
        );
    }

#endif
