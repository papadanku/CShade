
#include "cShade.fxh"
#include "cMath.fxh"
#include "cProcedural.fxh"

#if !defined(INCLUDE_CMOTIONESTIMATION)
    #define INCLUDE_CMOTIONESTIMATION

    // [-1.0, 1.0] -> [Width, Height]
    float2 CMotionEstimation_UnnormalizeMV(float2 Vectors, float2 ImageSize)
    {
        return Vectors / abs(ImageSize);
    }

    // [Width, Height] -> [-1.0, 1.0]
    float2 CMotionEstimation_NormalizeMV(float2 Vectors, float2 ImageSize)
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

    float2 CMotionEstimation_GetPixelPyLK
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0,
        sampler2D SampleI1
    )
    {
        // Initialize variables
        float4 WarpTex;
        float IxIx = 0.0;
        float IyIy = 0.0;
        float IxIy = 0.0;
        float IxIt = 0.0;
        float IyIt = 0.0;
        float SSD = 0.0;

        // Initiate main & warped texture coordinates
        WarpTex = MainTex.xyxy;

        // Convert motion vectors from Half -> [-0.5, 0.5) range
        Vectors = CMath_HalfToNorm(Vectors);

        // Calculate warped texture coordinates
        WarpTex.zw -= 0.5; // Pull into [-0.5, 0.5) range
        WarpTex.zw += Vectors; // Warp in [-HalfMax, HalfMax) range
        WarpTex.zw = saturate(WarpTex.zw + 0.5); // Push and clamp into [0.0, 1.0) range

        // Get gradient information
        float4 TexIx = ddx(WarpTex);
        float4 TexIy = ddy(WarpTex);
        float2 PixelSize = abs(TexIx.xy) + abs(TexIy.xy);
        float2x2 Rotation = CMath_GetRotationMatrix(45.0);

        // Get required data to calculate main window data
        const int WindowSize = 3;
        const int WindowHalf = trunc(WindowSize / 2);

        [loop] for (int i = 0; i < (WindowSize * WindowSize); i++)
        {
            float2 AngleShift = -WindowHalf + float2(i % WindowSize, trunc(i / WindowSize));
            AngleShift = mul(Rotation, AngleShift);

            // Get temporal gradient
            float4 TexIT = WarpTex.xyzw + (AngleShift.xyxy * PixelSize.xyxy);
            float2 I0 = tex2Dgrad(SampleI0, TexIT.xy, TexIx.xy, TexIy.xy).rg;
            float2 I1 = tex2Dgrad(SampleI1, TexIT.zw, TexIx.zw, TexIy.zw).rg;
            float2 IT = I0 - I1;

            // Get spatial gradient
            float4 OffsetNS = AngleShift.xyxy + float4(0.0, -1.0, 0.0, 1.0);
            float4 OffsetEW = AngleShift.xyxy + float4(-1.0, 0.0, 1.0, 0.0);
            float4 NS = WarpTex.xyxy + (OffsetNS * PixelSize.xyxy);
            float4 EW = WarpTex.xyxy + (OffsetEW * PixelSize.xyxy);
            float2 N = tex2Dgrad(SampleI0, NS.xy, TexIx.xy, TexIy.xy).rg;
            float2 S = tex2Dgrad(SampleI0, NS.zw, TexIx.xy, TexIy.xy).rg;
            float2 E = tex2Dgrad(SampleI0, EW.xy, TexIx.xy, TexIy.xy).rg;
            float2 W = tex2Dgrad(SampleI0, EW.zw, TexIx.xy, TexIy.xy).rg;
            float2 Ix = E - W;
            float2 Iy = N - S;

            // IxIx = A11; IyIy = A22; IxIy = A12/A22
            IxIx += dot(Ix, Ix);
            IyIy += dot(Iy, Iy);
            IxIy += dot(Ix, Iy);

            // IxIt = B1; IyIt = B2
            IxIt += dot(Ix, IT);
            IyIt += dot(Iy, IT);

            SSD += dot(IT, IT);
        }

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] [-IxIt]
            [-IxIy/D  Iy^2/D] [-IyIt]
        */

        /*
            Create a normalized SSD-based mask.
            https://www.cs.huji.ac.il/~peleg/papers/HUJI-CSE-LTR-2006-39-LK-Plus.pdf
        */

        float M = (SSD / (IxIx + IyIy)) < 1.0;
        IxIx *= M;
        IyIy *= M;
        IxIy *= M;
        IxIt *= M;
        IyIt *= M;

        // Calculate A^-1 and B
        float D = determinant(float2x2(IxIx, IxIy, IxIy, IyIy));
        float2x2 A = float2x2(IyIy, -IxIy, -IxIy, IxIx) / D;
        float2 B = float2(-IxIt, -IyIt);

        // Calculate A^T*B
        float2 Flow = (D > 0.0) ? mul(B, A) : 0.0;

        // Propagate normalized motion vectors in Norm Range
        Vectors += (Flow * PixelSize);

        // Clamp motion vectors to restrict range to valid lengths
        Vectors = clamp(Vectors, -1.0, 1.0);

        // Pack motion vectors to Half format
        return CMath_NormToHalf(Vectors);
    }

#endif
