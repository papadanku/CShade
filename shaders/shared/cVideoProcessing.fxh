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
        float2 MainTex;
        float2 Size;
        float2 LOD;
    };

    struct UnpackedTex
    {
        float4 Tex;
        float4 WarpedTex;
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

    float4 GetSobel(sampler2D Source, Texel Tex, float2 TexShift, float4 Mask)
    {
        // Pack normalization and masking into 1 operation
        float4 HalfPixel = (Tex.MainTex.xxyy + TexShift.xxyy) + float4(-0.5, 0.5, -0.5, 0.5);

        float4 OutputColor = 0.0;
        float2 A = tex2Dlod(Source, (HalfPixel.xwww * Mask) + Tex.LOD.xxxy).rg; // <-0.5, +0.5>
        float2 B = tex2Dlod(Source, (HalfPixel.ywww * Mask) + Tex.LOD.xxxy).rg; // <+0.5, +0.5>
        float2 C = tex2Dlod(Source, (HalfPixel.xzzz * Mask) + Tex.LOD.xxxy).rg; // <-0.5, -0.5>
        float2 D = tex2Dlod(Source, (HalfPixel.yzzz * Mask) + Tex.LOD.xxxy).rg; // <+0.5, -0.5>
        OutputColor.xz = ((B + D) - (A + C));
        OutputColor.yw = ((A + B) - (C + D));

        return OutputColor;
    }

    float2 GetPixelPyLK
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0,
        sampler2D SampleI1,
        int Level,
        bool Coarse
    )
    {
        // Initialize variables
        float3 A = 0.0;
        float2 B = 0.0;
        float Determinant = 0.0;
        float2 NewVectors = 0.0;

        // Calculate main texel information (TexelSize, TexelLOD)
        Texel TexInfo;
        TexInfo.Size.x = ddx(MainTex.x);
        TexInfo.Size.y = ddy(MainTex.y);
        TexInfo.MainTex = MainTex * (1.0 / abs(TexInfo.Size));
        TexInfo.LOD = float2(0.0, float(Level));
        float4 Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(TexInfo.Size.xyyy);

        // Decode written vectors from coarser level
        Vectors = DecodeVectors(Vectors, TexInfo.Size);

        for (int x = -3; x <= 3; x++)
        for (int y = -3; y <= 3; y++)
        {
            int2 Shift = int2(x, y);
            float2 Tex = TexInfo.MainTex + Shift;
            float4 Tex0 = (Tex.xyyy * Mask) + TexInfo.LOD.xxxy;
            float4 Tex1 = ((Tex.xyyy + Vectors.xyyy) * Mask) + TexInfo.LOD.xxxy;

            float2 I0 = tex2Dlod(SampleI0, Tex0).rg;
            float2 I1 = tex2Dlod(SampleI1, Tex1).rg;
            float4 G = GetSobel(SampleI0, TexInfo, Shift, Mask);

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
        return EncodeVectors(Vectors + NewVectors, TexInfo.Size);
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

    float4 SampleBlock(sampler2D Source, Texel Tex, float2 TexShift)
    {
        // Pack normalization and masking into 1 operation
        float4 Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(Tex.Size.xyyy);
        float4 HalfPixel = (Tex.MainTex.xxyy + TexShift.xxyy) + float4(-0.5, 0.5, -0.5, 0.5);

        float4 OutputColor = 0.0;
        OutputColor.x = tex2Dlod(Source, (HalfPixel.xzzz * Mask) + Tex.LOD.xxxy).r;
        OutputColor.y = tex2Dlod(Source, (HalfPixel.xwww * Mask) + Tex.LOD.xxxy).r;
        OutputColor.z = tex2Dlod(Source, (HalfPixel.yzzz * Mask) + Tex.LOD.xxxy).r;
        OutputColor.w = tex2Dlod(Source, (HalfPixel.ywww * Mask) + Tex.LOD.xxxy).r;

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

    float2 SearchArea(sampler2D S1, Texel Tex, float4 PBlock, float Minimum)
    {
        float2 Vectors = 0.0;
        for (int x = 1; x < 4; ++x)
        for (int y = 0; y < (4 * x); ++y)
        {
            float F = 6.28 / (4 * x);
            float2 Shift = float2(sin(F * y), cos(F * y)) * x;

            float4 CBlock = SampleBlock(S1, Tex, Shift);
            float NCC = GetNCC(PBlock, CBlock);

            if (NCC > Minimum)
            {
                Vectors = Shift;
                Minimum = NCC;
            }
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
        // Calculate main texel information (TexelSize, TexelLOD)
        Texel TexInfo;
        TexInfo.Size.x = ddx(MainTex.x);
        TexInfo.Size.y = ddy(MainTex.y);

        // Decode written vectors from coarser level
        Vectors = DecodeVectors(Vectors, TexInfo.Size);
        TexInfo.MainTex = (MainTex / abs(TexInfo.Size)) + Vectors;
        TexInfo.LOD = float2(0.0, float(Level));

        // Initialize variables
        float2 NewVectors = 0.0;
        float4 CBlock = SampleBlock(SampleI0, TexInfo, 0.0);
        float4 PBlock = SampleBlock(SampleI1, TexInfo, 0.0);
        float Minimum = GetNCC(PBlock, CBlock) + 1e-6;

        // Calculate three-step search
        NewVectors = SearchArea(SampleI1, TexInfo, CBlock, Minimum);

        // Propagate and encode vectors
        return EncodeVectors(Vectors + NewVectors, TexInfo.Size);
    }
#endif
