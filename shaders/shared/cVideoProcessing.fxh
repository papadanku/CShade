#include "cGraphics.fxh"
#include "cImageProcessing.fxh"

#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

    /*
        [Functions]
    */

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

    /*
        Lucas-Kanade optical flow with bilinear fetches
        ---
        Calculate Lucas-Kanade optical flow by solving (A^-1 * B)
        [A11 A12]^-1 [-B1] -> [ A11/D -A12/D] [-B1]
        [A21 A22]^-1 [-B2] -> [-A21/D  A22/D] [-B2]
        ---
        [ Ix^2/D -IxIy/D] [-IxIt]
        [-IxIy/D  Iy^2/D] [-IyIt]
    */

    struct Texel
    {
        float4 MainTex;
        float4 Mask;
        float4 LOD;
    };

    float2x2 GetGradients(sampler2D Source, float2 Tex, Texel Input)
    {
        float4 NS = Tex.xyxy + float4(0.0, -1.0, 0.0, 1.0);
        float4 EW = Tex.xyxy + float4(-1.0, 0.0, 1.0, 0.0);

        float2 N = tex2Dlod(Source, (NS.xyyy * Input.Mask) + Input.LOD.xxxy).rg;
        float2 S = tex2Dlod(Source, (NS.zwww * Input.Mask) + Input.LOD.xxxy).rg;
        float2 E = tex2Dlod(Source, (EW.xyyy * Input.Mask) + Input.LOD.xxxy).rg;
        float2 W = tex2Dlod(Source, (EW.zwww * Input.Mask) + Input.LOD.xxxy).rg;

        float2x2 OutputColor;
        OutputColor[0] = E - W;
        OutputColor[1] = N - S;
        return OutputColor;
    }

    float2 GetPixelPyLK
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0,
        sampler2D SampleI1
    )
    {
        // Initialize variables
        Texel TxData;
        float IxIx = 0.0;
        float IyIy = 0.0;
        float IxIy = 0.0;
        float IxIt = 0.0;
        float IyIt = 0.0;

        // Get required data to calculate main texel data
        const int WindowSize = 4;
        const float2 WindowHalf = trunc(WindowSize / 2) - 0.5;
        const float2 ImageSize = tex2Dsize(SampleI0, 0.0);
        float2 PixelSize = float2(ddx(MainTex.x),  ddy(MainTex.y));

        // Calculate main texel data (TexelSize, TexelLOD)
        TxData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(PixelSize.xyyy);
        TxData.MainTex.xy = MainTex;
        TxData.MainTex.zw = TxData.MainTex.xy + Vectors;
        TxData.LOD.xy = GetLOD(TxData.MainTex.xy * ImageSize);
        TxData.LOD.zw = GetLOD(TxData.MainTex.zw * ImageSize);

        // Un-normalize data for processing
        TxData.MainTex *= (1.0 / abs(PixelSize.xyxy));
        Vectors = DecodeVectors(Vectors, PixelSize);

        // Start from the negative so we can process a window in 1 loop
        [loop] for (int i = 0; i < (WindowSize * WindowSize); i++)
        {
            float2 Shift = -WindowHalf + float2(i % WindowSize, trunc(i / WindowSize));
            float4 Tex = TxData.MainTex + Shift.xyxy;

            float2x2 G = GetGradients(SampleI0, Tex.xy, TxData);
            float2 I0 = tex2Dlod(SampleI0, (Tex.xyyy * TxData.Mask) + TxData.LOD.xxxy).rg;
            float2 I1 = tex2Dlod(SampleI1, (Tex.zwww * TxData.Mask) + TxData.LOD.zzzw).rg;
            float2 IT = I0 - I1;

            // A.x = A11; A.y = A22; A.z = A12/A22
            IxIx += dot(G[0].rg, G[0].rg);
            IyIy += dot(G[1].rg, G[1].rg);
            IxIy += dot(G[0].rg, G[1].rg);

            // B.x = B1; B.y = B2
            IxIt += dot(G[0].rg, IT.rg);
            IyIt += dot(G[1].rg, IT.rg);
        }

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] [-IxIt]
            [-IxIy/D  Iy^2/D] [-IyIt]
        */

        // Calculate A^-1 and B
        float D = determinant(float2x2(IxIx, IxIy, IxIy, IyIy));
        float2x2 A = float2x2(IyIy, -IxIy, -IxIy, IxIx) / D;
        float2 B = float2(-IxIt, -IyIt);

        // Calculate A^T*B
        float2 Flow = (D == 0.0) ? 0.0 : mul(B, A);

        // Propagate and encode vectors
        return EncodeVectors(Vectors + Flow, PixelSize);
    }

    /*
        Modified version of VPlus' motion search algorithm
        ---
        https://github.com/bodhid/Vplus
        ---
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

    struct Block
    {
        float4 MainTex;
        float4 Mask;
        float4 LOD;
    };

    void SampleBlock(sampler2D Source, Block Input, float2 Tex, float2 LOD, out float2 Pixel[4])
    {
        float4 HalfPixel = Tex.xxyy + float4(-0.5, 0.5, -0.5, 0.5);
        Pixel[0] = tex2Dlod(Source, (HalfPixel.xzzz * Input.Mask) + LOD.xxxy).xy;
        Pixel[1] = tex2Dlod(Source, (HalfPixel.xwww * Input.Mask) + LOD.xxxy).xy;
        Pixel[2] = tex2Dlod(Source, (HalfPixel.yzzz * Input.Mask) + LOD.xxxy).xy;
        Pixel[3] = tex2Dlod(Source, (HalfPixel.ywww * Input.Mask) + LOD.xxxy).xy;
    }

    float GetSAD(float2 Template[4], float2 Image[4])
    {
        float2 SAD = 0.0;
        for(int i = 0; i < 4; i++)
        {
            SAD += abs(Template[i] - Image[i]);
        }
        return max(SAD[0], SAD[1]);
    }

    float2 SearchArea(sampler2D SampleImage, Block Input, float2 Template[4])
    {
        // Get constants
        const float Pi2 = acos(-1.0) * 2.0;

        // Initialize values
        float2 Vectors = 0.0;
        float2 Image[4];
        SampleBlock(SampleImage, Input, Input.MainTex.zw, Input.LOD.zw, Image);
        float Minimum = GetSAD(Template, Image);

    	[loop] for(int i = 1; i < 4; ++i)
        {
        	[loop] for(int j = 0; j < 4 * i; ++j)
            {
                float2 Shift = (Pi2 / (4.0 * float(i))) * float(j);
                sincos(Shift, Shift.x, Shift.y);

                float2 Tex = Input.MainTex.zw + (Shift * float(j));
                SampleBlock(SampleImage, Input, Tex, Input.LOD.zw, Image);
                float SAD = GetSAD(Template, Image);

                Vectors = (SAD < Minimum) ? Shift : Vectors;
                Minimum = min(SAD, Minimum);
            }
        }

        return Vectors;
    }

    float2 GetPixelMFlow
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleTemplate,
        sampler2D SampleImage,
        int Level
    )
    {
        // Initialize data
        Block BlockData;

        // Get required data to calculate main texel data
        const float2 ImageSize = tex2Dsize(SampleTemplate, 0.0);
        float2 PixelSize = float2(ddx(MainTex.x),  ddy(MainTex.y));

        // Calculate main texel data (TexelSize, TexelLOD)
        BlockData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(PixelSize.xyyy);
        BlockData.MainTex.xy = MainTex;
        BlockData.MainTex.zw = BlockData.MainTex.xy + Vectors;
        BlockData.LOD.xy = GetLOD(BlockData.MainTex.xy * ImageSize);
        BlockData.LOD.zw = GetLOD(BlockData.MainTex.zw * ImageSize);

        // Un-normalize data for processing
        BlockData.MainTex *= (1.0 / abs(PixelSize.xyxy));
        Vectors = DecodeVectors(Vectors, PixelSize);

        // Pre-calculate template
        float2 Template[4];
        SampleBlock(SampleTemplate, BlockData, BlockData.MainTex.xy, BlockData.LOD.xy, Template);

        // Calculate three-step search
        // Propagate and encode vectors
        Vectors += SearchArea(SampleImage, BlockData, Template);
        return EncodeVectors(Vectors, BlockData.Mask.xy);
    }
#endif
