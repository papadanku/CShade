
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
        float4 Tex3 : TEXCOORD3;
        float4 Tex4 : TEXCOORD4;
    };

    VS2PS_LK GetVertexPyLK(APP2VS Input, float2 PixelSize)
    {
        VS2PS_Quad FSQuad = VS_Quad(Input);

        VS2PS_LK Output;

        Output.HPos = FSQuad.HPos;
        Output.Tex0 = FSQuad.Tex0.xyxy;
        Output.Tex1 = FSQuad.Tex0.xxyy + (float4(-1.5, -0.5, 0.5, 1.5) * PixelSize.xxyy);
        Output.Tex2 = FSQuad.Tex0.xxyy + (float4(0.5, 1.5, 0.5, 1.5) * PixelSize.xxyy);
        Output.Tex3 = FSQuad.Tex0.xxyy + (float4(-1.5, -0.5, -0.5, -1.5) * PixelSize.xxyy);
        Output.Tex4 = FSQuad.Tex0.xxyy + (float4(0.5, 1.5, -0.5, -1.5) * PixelSize.xxyy);

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

    float2 GetPixelPyLK(VS2PS_LK Input, sampler2D SampleG, sampler2D SampleI0, sampler2D SampleI1, float2 Vectors)
    {
        // The spatial(S) and temporal(T) derivative neighbors to sample
        const int WindowSize = 16;
        float4 G[WindowSize];
        float2 I0[WindowSize];

        // Windows matrices to sum
        float3 A = 0.0;
        float2 B = 0.0;
        float Determinant = 0.0;
        float2 MotionVectors = 0.0;

        float2 WindowTex[WindowSize] =
        {
            Input.Tex1.xz, Input.Tex1.xw, Input.Tex1.yz, Input.Tex1.yw,
            Input.Tex2.xz, Input.Tex2.xw, Input.Tex2.yz, Input.Tex2.yw,
            Input.Tex3.xz, Input.Tex3.xw, Input.Tex3.yz, Input.Tex3.yw,
            Input.Tex4.xz, Input.Tex4.xw, Input.Tex4.yz, Input.Tex4.yw,
        };

        // Precalculate gradient matrix and I0
        for (int i = 0; i < WindowSize; i++)
        {
            // S[i].x = IxR; S[i].y = IxG; S[i].z = IyR; S[i].w = IyG;
            G[i] = tex2D(SampleG, WindowTex[i]).xyzw;
            I0[i] = tex2D(SampleI0, WindowTex[i]).rg;

            // A.x = A11; A.y = A22; A.z = A12/A22
            A.xyz += (G[i].xzx * G[i].xzz);
            A.xyz += (G[i].ywy * G[i].yww);
        }

        // Calculate right-hand-side
        for(int j = 0; j < WindowSize; j++)
        {
            // B.x = B1; B.y = B2
            float2 I1 = tex2D(SampleI1, WindowTex[j]).rg;
            float2 T = I0[j] - I1;
            B.xy += (G[j].xz * T.rr);
            B.xy += (G[j].yw * T.gg);
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
        MotionVectors = ((Vectors * 2.0) + MotionVectors);
        return MotionVectors;
    }
#endif
