
#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

    #include "cMacros.fxh"
    #include "cGraphics.fxh"

    // Lucas-Kanade optical flow with bilinear fetches

    struct VS2PS_LK
    {
        float4 HPos : SV_POSITION;
        float4 Tex0 : TEXCOORD0;
        float4 Tex1 : TEXCOORD1;
        float4 Tex2 : TEXCOORD2;
    };

    VS2PS_LK GetVertexPyLK(APP2VS Input, float2 PixelSize)
    {
        VS2PS_Quad FSQuad = VS_Quad(Input);

        VS2PS_LK Output;

        Output.HPos = FSQuad.HPos;
        Output.Tex0 = FSQuad.Tex0.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        Output.Tex1 = FSQuad.Tex0.xyyy + (float4( 0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        Output.Tex2 = FSQuad.Tex0.xyyy + (float4( 1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);

        return Output;
    }

    /*
        Calculate Lucas-Kanade optical flow by solving (A^-1 * B)
        [A11 A12]^-1 [-B1] -> [ A11 -A12] [-B1]
        [A21 A22]^-1 [-B2] -> [-A21  A22] [-B2]
        A11 = Ix^2
        A12 = IxIy
        A21 = IxIy
        A22 = Iy^2
        B1 = IxIt
        B2 = IyIt
    */

    struct UnpackedTex
    {
        float2 Tex;
        float2 WarpedTex;
        float LOD;
    };

    void UnpackTex(in float4 Tex, in float2 Vectors, out UnpackedTex Output[3])
    {
        // Calculate texture attributes of each packed column of tex
        float4 Ix = ddx(Tex);
        float4 Iy = ddy(Tex);
        float4 TexSize = float4(Ix.x, Iy.yzw);
        float4 WarpPackedTex = Tex + (Vectors.xyyy * TexSize);

        // Unpack texture and its attributes
        Output[0].Tex = Tex.xy;
        Output[1].Tex = Tex.xz;
        Output[2].Tex = Tex.xw;

        Output[0].WarpedTex = WarpPackedTex.xy;
        Output[1].WarpedTex = WarpPackedTex.xz;
        Output[2].WarpedTex = WarpPackedTex.xw;

        Output[0].LOD = log2(max(length(Ix.xy), length(Iy.xy)));
        Output[1].LOD = log2(max(length(Ix.xz), length(Iy.xz)));
        Output[2].LOD = log2(max(length(Ix.xw), length(Iy.xw)));
    }

    float2 GetPixelPyLK(VS2PS_LK Input, sampler2D SampleG, sampler2D SampleI0, sampler2D SampleI1, float2 Vectors, int MipLevel, bool CoarseLevel)
    {
        Vectors = Vectors * 2.0;

        // The spatial(S) and temporal(T) derivative neighbors to sample
        const int WindowSize = 9;

        UnpackedTex TexA[3];
        UnpackedTex TexB[3];
        UnpackedTex TexC[3];

        UnpackTex(Input.Tex0, Vectors, TexA);
        UnpackTex(Input.Tex1, Vectors, TexB);
        UnpackTex(Input.Tex2, Vectors, TexC);

        UnpackedTex Pixel[WindowSize] =
        {
            TexA[0], TexA[1], TexA[2],
            TexB[0], TexB[1], TexB[2],
            TexC[0], TexC[1], TexC[2],
        };

        // Windows matrices to sum
        float3 A = 0.0;
        float2 B = 0.0;

        float Determinant = 0.0;
        float2 MotionVectors = 0.0;

        // Calculate resigual from previous run
        float2 R = 0.0;
        R += tex2Dlod(SampleI1, float4(Pixel[5].WarpedTex, 0.0, Pixel[5].LOD)).rg;
        R -= tex2Dlod(SampleI0, float4(Pixel[5].Tex, 0.0, Pixel[5].LOD)).rg;
        R = pow(abs(R), 2.0);

        bool2 Converged = false;

        if((CoarseLevel == false) && (R.r < 0.5))
        {
            Converged.r = true;
        }

        if((CoarseLevel == false) && (R.g < 0.5))
        {
            Converged.g = true;
        }

        [branch]
        if(Converged.r == false)
        {
            [unroll]
            for(int i = 0; i < WindowSize; i++)
            {
                // B.x = B1; B.y = B2
                float I1 = tex2Dlod(SampleI1, float4(Pixel[i].WarpedTex, 0.0, Pixel[i].LOD)).r;
                float I0 = tex2Dlod(SampleI0, float4(Pixel[i].Tex, 0.0, Pixel[i].LOD)).r;
                float IT = I0 - I1;

                // A.x = A11; A.y = A22; A.z = A12/A22
                float2 G = tex2Dlod(SampleG, float4(Pixel[i].Tex, 0.0, Pixel[i].LOD)).xz;
                A.xyz += (G.xyx * G.xyy);
                B.xy += (G.xy * IT);
            }
        }

        [branch]
        if(Converged.g == false)
        {
            [unroll]
            for(int i = 0; i < WindowSize; i++)
            {
                // B.x = B1; B.y = B2
                float I1 = tex2Dlod(SampleI1, float4(Pixel[i].WarpedTex, 0.0, Pixel[i].LOD)).g;
                float I0 = tex2Dlod(SampleI0, float4(Pixel[i].Tex, 0.0, Pixel[i].LOD)).g;
                float IT = I0 - I1;

                // A.x = A11; A.y = A22; A.z = A12/A22
                float2 G = tex2Dlod(SampleG, float4(Pixel[i].Tex, 0.0, Pixel[i].LOD)).yw;
                A.xyz += (G.xyx * G.xyy);
                B.xy += (G.xy * IT);
            }
        }

        // Create -IxIy (A12) for A^-1 and its determinant
        A.z = -A.z;

        // Make determinant non-zero
        A.xy = A.xy + FP16_SMALLEST_SUBNORMAL;

        // Calculate A^-1 determinant
        Determinant = ((A.x * A.y) - (A.z * A.z));

        // Solve A^-1
        A = A / Determinant;

        // Calculate Lucas-Kanade matrix
        MotionVectors = mul(-B.xy, float2x2(A.yzzx));
        MotionVectors = (Determinant != 0.0) ? MotionVectors : 0.0;

        // Propagate (add) vectors
        // Do not multiply on the finest level
        MotionVectors = (Vectors + MotionVectors);
        return MotionVectors;
    }
#endif
