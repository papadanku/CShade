
#include "cShade.fxh"
#include "cMath.fxh"
#include "cProcedural.fxh"

#if !defined(INCLUDE_CMOTIONESTIMATION)
    #define INCLUDE_CMOTIONESTIMATION

    /*
        Lucas-Kanade optical flow with bilinear fetches.
        ---
        The algorithm is motified to not output in pixels, but normalized displacements
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

        // Initiate main & warped texture coordinates
        WarpTex = MainTex.xyxy;

        // Decode from FP16
        Vectors = CMath_FP16ToNorm(Vectors);

        // Calculate warped texture coordinates
        WarpTex.zw -= 0.5; // Pull into [-0.5, 0.5) range
        WarpTex.zw += Vectors; // Warp in [-HalfMax, HalfMax) range
        WarpTex.zw = saturate(WarpTex.zw + 0.5); // Push and clamp into [0.0, 1.0) range

        // Get gradient information
        float2 TexIx = ddx(WarpTex.xy);
        float2 TexIy = ddy(WarpTex.xy);
        float2 PixelSize = abs(TexIx) + abs(TexIy);

        // Get required data to calculate main window data
        const int WindowSize = 3;
        const int WindowHalf = trunc(WindowSize / 2);

        [loop] for (int i = 0; i < (WindowSize * WindowSize); i++)
        {
            float2 Shift = -WindowHalf + float2(i % WindowSize, trunc(i / WindowSize));

            // Get temporal gradient
            float4 TexIT = WarpTex.xyzw + (Shift.xyxy * PixelSize.xyxy);
            float2 I0 = tex2Dgrad(SampleI0, TexIT.xy, TexIx, TexIy).rg;
            float2 I1 = tex2Dgrad(SampleI1, TexIT.zw, TexIx, TexIy).rg;
            float2 IT = I0 - I1;

            // Get spatial gradient
            float4 OffsetNS = Shift.xyxy + float4(0.0, -1.0, 0.0, 1.0);
            float4 OffsetEW = Shift.xyxy + float4(-1.0, 0.0, 1.0, 0.0);
            float4 NS = WarpTex.xyxy + (OffsetNS * PixelSize.xyxy);
            float4 EW = WarpTex.xyxy + (OffsetEW * PixelSize.xyxy);
            float2 N = tex2Dgrad(SampleI0, NS.xy, TexIx, TexIy).rg;
            float2 S = tex2Dgrad(SampleI0, NS.zw, TexIx, TexIy).rg;
            float2 E = tex2Dgrad(SampleI0, EW.xy, TexIx, TexIy).rg;
            float2 W = tex2Dgrad(SampleI0, EW.zw, TexIx, TexIy).rg;
            float2 Ix = E - W;
            float2 Iy = N - S;

            // IxIx = A11; IyIy = A22; IxIy = A12/A22
            IxIx += dot(Ix, Ix);
            IyIy += dot(Iy, Iy);
            IxIy += dot(Ix, Iy);

            // IxIt = B1; IyIt = B2
            IxIt += dot(Ix, IT);
            IyIt += dot(Iy, IT);
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
        float2 Flow = (D > 0.0) ? mul(B, A) : 0.0;

        // Normalize motion vectors
        Flow *= PixelSize;

        // Remove outliers
        Flow = (abs(Flow) > 1.0) ? 0.0 : Flow;

        // Propagate normalized motion vectors in Norm Range
        Vectors += Flow;

        // Clamp motion vectors to restrict range to valid lengths
        Vectors = clamp(Vectors, -1.0, 1.0);

        // Encode motion vectors to FP16 format
        return CMath_NormToFP16(Vectors);
    }

#endif
