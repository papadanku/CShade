
#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

    #include "shared/cMacros.fxh"
    #include "shared/cGraphics.fxh"

    // Lucas-Kanade optical flow with bilinear fetches

    /*
        Calculate Lucas-Kanade optical flow by solving (A^-1 * B)
        ---------------------------------------------------------
        [A11 A12]^-1 [-B1] -> [ A11 -A12] [-B1]
        [A21 A22]^-1 [-B2] -> [-A21  A22] [-B2]
        ---------------------------------------------------------
        [ Ix^2 -IxIy] [-IxIt]
        [-IxIy  Iy^2] [-IyIt]
    */

    float2 GetEigenValue(float3 G)
    {
        float A = (G.x + G.y) * 0.5;
        float C = sqrt((4.0 * pow(G.z, 2)) + pow(G.x - G.y, 2)) * 0.5;
        float2 E = 0.0;
        E[0] = (A + C);
        E[1] = (A - C);
        return E;
    }

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

    // Unpacks and assembles a column of texture coordinates
    void UnpackTex(in Texel Tex, in float2 Vectors, out UnpackedTex Output[9])
    {
        const float4 TexMask = float4(1.0, 1.0, 0.0, 0.0);
        float4 TexOffsets[3];
        TexOffsets[0] = float4(-1.0, 1.0, 0.0, -1.0);
        TexOffsets[1] = float4(0.0, 1.0, 0.0, -1.0);
        TexOffsets[2] = float4(1.0, 1.0, 0.0, -1.0);

        // Calculate tex columns in 1 MAD
        int Index = 0;
        int TexIndex = 0;

        while(Index < 3)
        {
            float4 ColumnTex = Tex.MainTex.xyyy + (TexOffsets[Index] * abs(Tex.Size.xyyy));
            Output[TexIndex + 0].Tex = (ColumnTex.xyyy * TexMask) + Tex.LOD.xxxy;
            Output[TexIndex + 1].Tex = (ColumnTex.xzzz * TexMask) + Tex.LOD.xxxy;
            Output[TexIndex + 2].Tex = (ColumnTex.xwww * TexMask) + Tex.LOD.xxxy;

            float4 WarpedColumnTex = ColumnTex + (Vectors.xyyy * abs(Tex.Size.xyyy));
            Output[TexIndex + 0].WarpedTex = (WarpedColumnTex.xyyy * TexMask) + Tex.LOD.xxxy;
            Output[TexIndex + 1].WarpedTex = (WarpedColumnTex.xzzz * TexMask) + Tex.LOD.xxxy;
            Output[TexIndex + 2].WarpedTex = (WarpedColumnTex.xwww * TexMask) + Tex.LOD.xxxy;

            Index = Index + 1;
            TexIndex = TexIndex + 3;
        }
    }

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

    float2 GetPixelPyLK
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0_G,
        sampler2D SampleI0,
        sampler2D SampleI1,
        bool CoarseLevel
    )
    {
        // Setup constants
        const int WindowSize = 9;

        // Initialize variables
        float3 A = 0.0;
        float4 B = 0.0;
        float2 E = 0.0;
        float4 G[WindowSize];
        bool Refine = false;
        float Determinant = 0.0;
        float2 MVectors = 0.0;

        // Calculate main texel information (TexelSize, TexelLOD)
        Texel TexInfo;
        TexInfo.MainTex = MainTex;
        float2 Ix = ddx(TexInfo.MainTex);
        float2 Iy = ddy(TexInfo.MainTex);
        float DPX = dot(Ix, Ix);
        float DPY = dot(Iy, Iy);
        TexInfo.Size.x = Ix.x;
        TexInfo.Size.y = Iy.y;
        // log2(x^n) = n*log2(x)
        TexInfo.LOD = float2(0.0, 0.5) * log2(max(DPX, DPY));

        // Decode written vectors from coarser level
        Vectors = DecodeVectors(Vectors, TexInfo.Size);

        // The spatial(S) and temporal(T) derivative neighbors to sample
        UnpackedTex Pixel[WindowSize];
        UnpackTex(TexInfo, Vectors, Pixel);

        [unroll]
        for(int i = 0; i < WindowSize; i++)
        {
            // A.x = A11; A.y = A22; A.z = A12/A22
            G[i] = tex2Dlod(SampleI0_G, Pixel[i].Tex);
            A.xyz += (G[i].xzx * G[i].xzz);
            A.xyz += (G[i].ywy * G[i].yww);
        }

        E = GetEigenValue(A);

        // Calculate green channel of optical flow

        if(CoarseLevel == true)
        {
            Refine = true;
        }
        else if(min(E[0], E[1]) <= 0.001)
        {
            Refine = false;
        }
        else
        {
            Refine = true;
        }

        [flatten]
        if(Refine == true)
        {
            // Calculate IT and Sum of Squared Differences
            [unroll]
            for(int i = 0; i < WindowSize; i++)
            {
                float2 I0 = tex2Dlod(SampleI0, Pixel[i].Tex).rg;
                float2 I1 = tex2Dlod(SampleI1, Pixel[i].WarpedTex).rg;
                float2 IT = I0 - I1;

                // B.x = B1; B.y = B2
                B += (G[i].xzyw * IT.rrgg);
            }
        }

        B.xy = B.xy + B.zw;

        // Create -IxIy (A12) for A^-1 and its determinant
        A.z = -A.z;

        // Calculate A^-1 determinant
        Determinant = (A.x * A.y) - (A.z * A.z);

        // Solve A^-1
        A = A / Determinant;

        // Calculate Lucas-Kanade matrix
        MVectors = mul(-B.xy, float2x2(A.yzzx));
        MVectors = (Determinant != 0.0) ? MVectors : 0.0;

        // Propagate and encode vectors
        MVectors = EncodeVectors(Vectors + MVectors, TexInfo.Size);
        return MVectors;
    }
#endif
