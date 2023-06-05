#include "cGraphics.fxh"
#include "cImageProcessing.fxh"

#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

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
        float Determinant = 0.0;
        float2 NewVectors = 0.0;

        // Get required data to calculate main texel data
        float2 TexSize = float2(ddx(MainTex.x), ddy(MainTex.y));
        Vectors = DecodeVectors(Vectors, TexSize);

        // Calculate main texel data (TexelSize, TexelLOD)
        TxData.Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(TexSize.xyyy);
        TxData.MainTex.xy = MainTex * (1.0 / abs(TexSize));
        TxData.MainTex.zw = TxData.MainTex.xy + Vectors;
        TxData.LOD = float2(0.0, float(Level));

        [loop]
        for (float x = -1.5; x <= 1.5; x++)
        [loop]
        for (float y = -1.5; y <= 1.5; y++)
        {
            const float2 Shift = float2(x, y);
            float4 Tex = TxData.MainTex + Shift.xyxy;
            float4 Tex0 = (Tex.xyyy * TxData.Mask) + TxData.LOD.xxxy;
            float4 Tex1 = (Tex.zwww * TxData.Mask) + TxData.LOD.xxxy;

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

        // Create -IxIy (A12) for A^-1 and its determinant
        A.z = -A.z;

        // Calculate A^-1 determinant
        Determinant = (A.x * A.y) - (A.z * A.z);

        // Solve A^-1
        A = A / Determinant;

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] [-IxIt]
            [-IxIy/D  Iy^2/D] [-IyIt]
        */
        NewVectors = (Determinant != 0.0) ? mul(-B.xy, float2x2(A.yzzx)) : 0.0;

        // Propagate and encode vectors
        return EncodeVectors(Vectors + NewVectors, TxData.Mask.xy);
    }

    struct Block
    {
        float4 MainTex;
        float4 Mask;
        float2 LOD;
    };

    void StoreTemplate(sampler2D Source, Block Input, out float4 Template[8])
    {
        int ID = 0;
        [unroll]
        for (float y = -1.5; y <= 1.5; y += 1.0)
        [unroll]
        for (float x = -1.5; x <= 1.5; x += 2.0)
        {
            const float4 Shift = float4(x, y, x + 1.0, y);
            float4 Tex = Input.MainTex.xyxy + Shift.xyxy;
            Template[ID].xy = tex2Dlod(Source, (Tex.xyyy * Input.Mask) + Input.LOD.xxxy).rg;
            Template[ID].zw = tex2Dlod(Source, (Tex.zwww * Input.Mask) + Input.LOD.xxxy).rg;
            ID += 1;
        }
    }

    float GetNCC(sampler2D SampleImage, Block Input, float2 Tex, float4 Template[8])
    {
        int ID = 0;
        float2 N1;
        float2 N2;
        float2 N3;

        [unroll]
        for (float y = -1.5; y <= 1.5; y += 1.0)
        [unroll]
        for (float x = -1.5; x <= 1.5; x += 2.0)
        {
            const float4 Shift = float4(x, y, x + 1.0, y);
            float4 Tex = Input.MainTex.xyxy + Shift.xyxy;

            float4 T = Template[ID];
            float4 I =
            {
                tex2Dlod(SampleImage, (Tex.xyyy * Input.Mask) + Input.LOD.xxxy).rg,
                tex2Dlod(SampleImage, (Tex.zwww * Input.Mask) + Input.LOD.xxxy).rg
            };

            N1.r += dot(T[i].xz, I[i].xz);
            N2.r += dot(T[i].xz, T[i].xz);
            N3.r += dot(I[i].xz, I[i].xz);

            N1.g += dot(T[i].yw, I[i].yw);
            N2.g += dot(T[i].yw, T[i].yw);
            N3.g += dot(I[i].yw, I[i].yw);

            ID += 1;
        }

        float2 NCC = N1 * rsqrt(N2 * N3);
        return min(NCC[0], NCC[1]);
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

            float2 ImageTex = Input.MainTex.zw + Shift;
            float NCC = GetNCC(SampleImage, Input, ImageTex, Template);
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

        // Initialize variables
        float4 Template[8];
        StoreTemplate(SampleTemplate, BlockData, Template);
        float Minimum = GetNCC(SampleImage, BlockData, BlockData.MainTex.zw, Template);

        // Calculate three-step search
        Vectors += SearchArea(SampleImage, BlockData, Template, Minimum);

        // Propagate and encode vectors
        return EncodeVectors(Vectors, BlockData.Mask.xy);
    }
#endif
