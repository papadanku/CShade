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

    float2x3 GetGradients(sampler2D Source, float2 Tex, Texel Input)
    {
        float4 NS = Tex.xyxy + float4(0.0, -1.0, 0.0, 1.0);
        float4 EW = Tex.xyxy + float4(-1.0, 0.0, 1.0, 0.0);

        float3 N = GetRGB(tex2Dlod(Source, (NS.xyyy * Input.Mask) + Input.LOD.xxxy).rg);
        float3 S = GetRGB(tex2Dlod(Source, (NS.zwww * Input.Mask) + Input.LOD.xxxy).rg);
        float3 E = GetRGB(tex2Dlod(Source, (EW.xyyy * Input.Mask) + Input.LOD.xxxy).rg);
        float3 W = GetRGB(tex2Dlod(Source, (EW.zwww * Input.Mask) + Input.LOD.xxxy).rg);

        float2x3 OutputColor;
        OutputColor[0] = E - W;
        OutputColor[1] = N - S;
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
        Texel TxData;
        float3 A = 0.0;
        float2 B = 0.0;

        // Get required data to calculate main texel data
        float2 WarpTex = MainTex + Vectors;
        float2 Ix[2] = { ddx(MainTex), ddx(WarpTex) };
        float2 Iy[2] = { ddy(MainTex), ddy(WarpTex) };
        float2 TSize = float2(Ix[0].x,  Iy[0].y);

        // Calculate main texel data (TexelSize, TexelLOD)
        TxData.MainTex = float4(MainTex, WarpTex);
        TxData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(TSize.xyyy);
        TxData.LOD.xy = GetLOD(TxData.MainTex.xy, Ix[0], Iy[0]);
        TxData.LOD.zw = GetLOD(TxData.MainTex.zw, Ix[1], Iy[1]);

        // Expand data to pixel range
        TxData.MainTex = TxData.MainTex * (1.0 / abs(TxData.Mask.xyxy));
        Vectors = DecodeVectors(Vectors, TxData.Mask.xy);

        [loop]
        for (float x = -1.5; x <= 1.5; x++)
        [loop]
        for (float y = -1.5; y <= 1.5; y++)
        {
            const float2 Shift = float2(x, y);
            float4 Tex = TxData.MainTex + Shift.xyxy;
            float4 Tex0 = (Tex.xyyy * TxData.Mask) + TxData.LOD.xxxy;
            float4 Tex1 = (Tex.zwww * TxData.Mask) + TxData.LOD.zzzw;

            float2x3 G = GetGradients(SampleI0, Tex.xy, TxData);
            float3 I0 = GetRGB(tex2Dlod(SampleI0, Tex0).rg);
            float3 I1 = GetRGB(tex2Dlod(SampleI1, Tex1).rg);
            float3 IT = I0 - I1;

            // A.x = A11; A.y = A22; A.z = A12/A22
            A.x += dot(G[0].rgb, G[0].rgb);
            A.y += dot(G[1].rgb, G[1].rgb);
            A.z += dot(G[0].rgb, G[1].rgb);

            // B.x = B1; B.y = B2
            B.x += dot(G[0].rgb, IT.rgb);
            B.y += dot(G[1].rgb, IT.rgb);
        }

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] [-IxIt]
            [-IxIy/D  Iy^2/D] [-IyIt]
        */

        // Create -IxIy (A12) for A^-1 and its determinant
        A.z = -A.z;

        // Calculate A^-1 determinant
        float D = determinant(float2x2(A.xzzy));

        // Calculate flow
        float2 Flow = (D == 0.0) ? 0.0 : mul(-B.xy, float2x2(A.yzzx / D));

        // Propagate and encode vectors
        return EncodeVectors(Vectors + Flow, TxData.Mask.xy);
    }

    struct Block
    {
        float4 MainTex;
        float4 Mask;
        float2 LOD;
        float4x4 Shifts;
    };

    void SampleBlock(sampler2D Source, float4x4 HalfPixel, Block Input, out float4 Pixel[8])
    {
        Pixel[0].xy = tex2Dlod(Source, (HalfPixel[0].xzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[1].xy = tex2Dlod(Source, (HalfPixel[0].xwww * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[2].xy = tex2Dlod(Source, (HalfPixel[0].yzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[3].xy = tex2Dlod(Source, (HalfPixel[0].ywww * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[4].xy = tex2Dlod(Source, (HalfPixel[1].xzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[5].xy = tex2Dlod(Source, (HalfPixel[1].xwww * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[6].xy = tex2Dlod(Source, (HalfPixel[1].yzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[7].xy = tex2Dlod(Source, (HalfPixel[1].ywww * Input.Mask) + Input.LOD.xxxy).xy;

        Pixel[0].zw = tex2Dlod(Source, (HalfPixel[2].xzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[1].zw = tex2Dlod(Source, (HalfPixel[2].xwww * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[2].zw = tex2Dlod(Source, (HalfPixel[2].yzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[3].zw = tex2Dlod(Source, (HalfPixel[2].ywww * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[4].zw = tex2Dlod(Source, (HalfPixel[3].xzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[5].zw = tex2Dlod(Source, (HalfPixel[3].xwww * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[6].zw = tex2Dlod(Source, (HalfPixel[3].yzzz * Input.Mask) + Input.LOD.xxxy).xy;
        Pixel[7].zw = tex2Dlod(Source, (HalfPixel[3].ywww * Input.Mask) + Input.LOD.xxxy).xy;
    }

    float GetNCC(float4 T[8], float4 I[8])
    {
        float2 N1;
        float2 N2;
        float2 N3;

        [unroll]
        for (int i = 0; i < 8; i++)
        {
            N1.r += dot(T[i].xz, I[i].xz);
            N2.r += dot(T[i].xz, T[i].xz);
            N3.r += dot(I[i].xz, I[i].xz);

            N1.g += dot(T[i].yw, I[i].yw);
            N2.g += dot(T[i].yw, T[i].yw);
            N3.g += dot(I[i].yw, I[i].yw);
        }

        float2 NCC = N1 * rsqrt(N2 * N3);
        return min(NCC[0], NCC[1]);
    }

    float4x4 GetHalfPixel(Block Input, float2 Tex)
    {
        float4x4 HalfPixel;
        HalfPixel[0] = Tex.xxyy + Input.Shifts[0];
        HalfPixel[1] = Tex.xxyy + Input.Shifts[1];
        HalfPixel[2] = Tex.xxyy + Input.Shifts[2];
        HalfPixel[3] = Tex.xxyy + Input.Shifts[3];
        return HalfPixel;
    }

    float2 SearchArea(sampler2D SampleImage, Block Input, float4 Template[8], float Minimum)
    {
        float2 Vectors = 0.0;

        [loop]
        for (int x = -1; x <= 1; x++)
        [loop]
        for (int y = -1; y <= 1; y++)
        {
            float2 Shift = int2(x, y);
            if (all(Shift == 0))
            {
                continue;
            }

            float4x4 HalfPixel = GetHalfPixel(Input, Input.MainTex.zw + Shift);
            float4 Image[8];
            SampleBlock(SampleImage, HalfPixel, Input, Image);
            float NCC = GetNCC(Template, Image);

            Vectors = (NCC > Minimum) ? Shift : Vectors;
            Minimum = max(NCC, Minimum);
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
        float2 TexSize = float2(ddx(MainTex.x), ddy(MainTex.y));
        Vectors = DecodeVectors(Vectors, TexSize);

        // Calculate main texel data (TexelSize, TexelLOD)
        BlockData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(TexSize.xyyy);
        BlockData.MainTex.xy = MainTex * (1.0 / abs(TexSize));
        BlockData.MainTex.zw = BlockData.MainTex.xy + Vectors;
        BlockData.LOD = float2(0.0, float(Level));
        BlockData.Shifts = float4x4
        (
            float4(-0.5, 0.5, -0.5, 0.5) + float4(-1.0, -1.0,  1.0,  1.0),
            float4(-0.5, 0.5, -0.5, 0.5) + float4( 1.0,  1.0,  1.0,  1.0),
            float4(-0.5, 0.5, -0.5, 0.5) + float4(-1.0, -1.0, -1.0, -1.0),
            float4(-0.5, 0.5, -0.5, 0.5) + float4( 1.0,  1.0, -1.0, -1.0)
        );

        // Initialize variables
        float4 Template[8];
        float4 Image[8];
        float4x4 HalfPixel = GetHalfPixel(BlockData, BlockData.MainTex.xy);
        SampleBlock(SampleTemplate, HalfPixel, BlockData, Template);
        SampleBlock(SampleImage, HalfPixel, BlockData, Image);
        float Minimum = GetNCC(Template, Image) + 1e-7;

        // Calculate three-step search
        Vectors += SearchArea(SampleImage, BlockData, Template, Minimum);

        // Propagate and encode vectors
        return EncodeVectors(Vectors, BlockData.Mask.xy);
    }
#endif
