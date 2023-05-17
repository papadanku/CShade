#include "cGraphics.fxh"

#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

    // Lucas-Kanade optical flow with bilinear fetches

    /*
        Calculate Lucas-Kanade optical flow by solving (A^-1 * B)
        ---------------------------------------------------------
        [A11 A12]^-1 [-B1] -> [ A11/D -A12/D] [-B1]
        [A21 A22]^-1 [-B2] -> [-A21/D  A22/D] [-B2]
        ---------------------------------------------------------
        [ Ix^2/D -IxIy/D] [-IxIt]
        [-IxIy/D  Iy^2/D] [-IyIt]
    */

    struct Texel
    {
        float4 MainTex;
        float4 Mask;
        float2 LOD;
    };

    // [-1.0, 1.0] -> [Width, Height]
    float2 DecodeVectors(float2 Vectors, float2 ImageSize)
    {
        return Vectors / abs(ImageSize);
    }

    // [Width, Height] -> [-1.0, 1.0]
    float2 EncodeVectors(float2 Vectors, float2 ImageSize)
    {
        return clamp(Vectors * abs(ImageSize), -1.0, 1.0);
    }

    float4 GetSobel(sampler2D Source, float2 Tex, Texel TexData)
    {
        float4 NS = Tex.xyxy + float4(0.0, -1.0, 0.0, 1.0);
        float4 EW = Tex.xyxy + float4(-1.0, 0.0, 1.0, 0.0);

        float4 OutputColor = 0.0;
        float2 N = tex2Dlod(Source, (NS.xyyy * TexData.Mask) + TexData.LOD.xxxy).rg;
        float2 S = tex2Dlod(Source, (NS.zwww * TexData.Mask) + TexData.LOD.xxxy).rg;
        float2 E = tex2Dlod(Source, (EW.xyyy * TexData.Mask) + TexData.LOD.xxxy).rg;
        float2 W = tex2Dlod(Source, (EW.zwww * TexData.Mask) + TexData.LOD.xxxy).rg;
        OutputColor.xz = E - W;
        OutputColor.yw = N - S;

        return OutputColor;
    }

    float2 GetPixelPyLK
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0,
        sampler2D SampleI1,
        int Level
    )
    {
        // Initialize variables
        Texel TexData;
        float3 A = 0.0;
        float2 B = 0.0;
        float Determinant = 0.0;
        float2 NewVectors = 0.0;

        // Get required data to calculate main texel data
        float2 TexSize = float2(ddx(MainTex.x), ddy(MainTex.y));
        Vectors = DecodeVectors(Vectors, TexSize);

        // Calculate main texel data (TexelSize, TexelLOD)
        TexData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(TexSize.xyyy);
        TexData.MainTex.xy = MainTex * (1.0 / abs(TexSize));
        TexData.MainTex.zw = TexData.MainTex.xy + Vectors;
        TexData.LOD = float2(0.0, float(Level));

        for (int x = -2.5; x <= 2.5; x++)
        for (int y = -2.5; y <= 2.5; y++)
        {
            int2 Shift = int2(x, y);
            float4 Tex = TexData.MainTex + Shift.xyxy;
            float4 Tex0 = (Tex.xyyy * TexData.Mask) + TexData.LOD.xxxy;
            float4 Tex1 = (Tex.zwww * TexData.Mask) + TexData.LOD.xxxy;

            float2 I0 = tex2Dlod(SampleI0, Tex0).rg;
            float2 I1 = tex2Dlod(SampleI1, Tex1).rg;
            float4 G = GetSobel(SampleI0, Tex.xy, TexData);

            // A.x = A11; A.y = A22; A.z = A12/A22
            A.xyz += (G.xyx * G.xyy);
            A.xyz += (G.zwz * G.zww);

            // B.x = B1; B.y = B2
            float2 IT = I0 - I1;
            B += (G.xy * IT.rr);
            B += (G.zw * IT.gg);
        }

        // Create -IxIy (A12) for A^-1 and its determinant
        A.z = -A.z;

        // Calculate A^-1 determinant
        Determinant = (A.x * A.y) - (A.z * A.z);

        // Solve A^-1
        A = A / Determinant;
 
        // Calculate Lucas-Kanade matrix
        // [ Ix^2/D -IxIy/D] [-IxIt]
        // [-IxIy/D  Iy^2/D] [-IyIt]
        NewVectors = (Determinant != 0.0) ? mul(-B.xy, float2x2(A.yzzx)) : 0.0;

        // Propagate and encode vectors
        return EncodeVectors(Vectors + NewVectors, TexData.Mask.xy);
    }

    /*
        MIT License

        Copyright (c) 2018 Bodhi Donselaar

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

    float4 SampleBlock(sampler2D Source, float2 Tex, Texel TexData)
    {
        // Pack normalization and masking into 1 operation
        float4 HalfPixel = Tex.xxyy + float4(-0.5, 0.5, -0.5, 0.5);

        float4 OutputColor = 0.0;
        OutputColor.x = tex2Dlod(Source, (HalfPixel.xzzz * TexData.Mask) + TexData.LOD.xxxy).r;
        OutputColor.y = tex2Dlod(Source, (HalfPixel.xwww * TexData.Mask) + TexData.LOD.xxxy).r;
        OutputColor.z = tex2Dlod(Source, (HalfPixel.yzzz * TexData.Mask) + TexData.LOD.xxxy).r;
        OutputColor.w = tex2Dlod(Source, (HalfPixel.ywww * TexData.Mask) + TexData.LOD.xxxy).r;

        return OutputColor;
    }

    float GetNCC(float4 P, float4 C)
    {
        float3 NCC = 0.0;
        for (int i = 0; i < 4; i++)
        {
            NCC[0] += (P[i] * P[i]);
            NCC[1] += (C[i] * C[i]);
            NCC[2] += (P[i] * C[i]);
        }
        return NCC[2] * rsqrt(NCC[0] * NCC[1]);
    }

    float2 SearchArea(sampler2D S1, Texel TexData, float4 PBlock, float Minimum)
    {
        float2 Vectors = 0.0;
        for (int x = 1; x < 4; ++x)
        for (int y = 0; y < (4 * x); ++y)
        {
            float F = 6.28 / (4 * x);
            float2 Shift = float2(sin(F * y), cos(F * y)) * x;

            float4 CBlock = SampleBlock(S1, TexData.MainTex.xy + Shift, TexData);
            float NCC = GetNCC(PBlock, CBlock);

            Vectors = (NCC > Minimum) ? Shift : Vectors;
            Minimum = max(NCC, Minimum);
        }
        return Vectors;
    }

    float2 GetPixelMFlow
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0,
        sampler2D SampleI1,
        int Level
    )
    {
        // Initialize data
        Texel TexData;

        // Get required data to calculate main texel data
        float2 TexSize = float2(ddx(MainTex.x), ddy(MainTex.y));
        Vectors = DecodeVectors(Vectors, TexSize);

        // Calculate main texel data (TexelSize, TexelLOD)
        TexData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(TexSize.xyyy);
        TexData.MainTex.xy = MainTex * (1.0 / abs(TexSize));
        TexData.MainTex.zw = MainTex + Vectors;
        TexData.LOD = float2(0.0, float(Level));

        // Initialize variables
        float2 NewVectors = 0.0;
        float4 CBlock = SampleBlock(SampleI0, TexData.MainTex.xy, TexData);
        float4 PBlock = SampleBlock(SampleI1, TexData.MainTex.xy, TexData);
        float Minimum = GetNCC(PBlock, CBlock) + 1e-6;

        // Calculate three-step search
        NewVectors = SearchArea(SampleI1, TexData, CBlock, Minimum);

        // Propagate and encode vectors
        return EncodeVectors(Vectors + NewVectors, TexData.Mask.xy);
    }
#endif
