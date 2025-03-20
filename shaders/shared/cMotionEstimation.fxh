
#include "cBlur.fxh"
#include "cShade.fxh"
#include "cMath.fxh"
#include "cProcedural.fxh"

#if !defined(INCLUDE_CMOTIONESTIMATION)
    #define INCLUDE_CMOTIONESTIMATION

    /*
        Dilate up to 2^2 pixels.
        - Subsequent levels and the post-filter upsampling will address the undersampled regions.
        - This idea is based off depth-of-field undersampling and using a post-filter on the undersampled regions.
    */
    float4 CMotionEstimation_GetDilatedPyramidUpsample(sampler2D SampleSource, float2 Tex)
    {
        // A0 B0 C0
        // A1 B1 C1
        // A2 B2 C2
        float2 Delta = fwidth(Tex) * exp2(2.0);
        float4 Tex0 = Tex.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * Delta.xyyy);
        float4 Tex1 = Tex.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * Delta.xyyy);
        float4 Tex2 = Tex.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * Delta.xyyy);

        float4 Sum = 0.0;
        float Weight = 1.0 / 9.0;
        Sum += (tex2D(SampleSource, Tex0.xy) * Weight);
        Sum += (tex2D(SampleSource, Tex0.xz) * Weight);
        Sum += (tex2D(SampleSource, Tex0.xw) * Weight);
        Sum += (tex2D(SampleSource, Tex1.xy) * Weight);
        Sum += (tex2D(SampleSource, Tex1.xz) * Weight);
        Sum += (tex2D(SampleSource, Tex1.xw) * Weight);
        Sum += (tex2D(SampleSource, Tex2.xy) * Weight);
        Sum += (tex2D(SampleSource, Tex2.xz) * Weight);
        Sum += (tex2D(SampleSource, Tex2.xw) * Weight);

        return Sum;
    }

    /*
        Lucas-Kanade optical flow with bilinear fetches. The algorithm is motified to not output in pixels, but normalized displacements.

        ---

        Gauss-Newton Steepest Descent Inverse Additive Algorithm

        Baker, S., & Matthews, I. (2004). Lucas-kanade 20 years on: A unifying framework. International journal of computer vision, 56, 221-255.

        https://www.researchgate.net/publication/248602429_Lucas-Kanade_20_Years_On_A_Unifying_Framework_Part_1_The_Quantity_Approximated_the_Warp_Update_Rule_and_the_Gradient_Descent_Approximation
    */

    float2 CMotionEstimation_GetPixelPyLK
    (
        float2 MainPos,
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleT,
        sampler2D SampleI
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
        Vectors = clamp(CMath_Float2_FP16ToNorm(Vectors), -1.0, 1.0);

        // Calculate warped texture coordinates
        WarpTex.zw -= 0.5; // Pull into [-0.5, 0.5) range
        WarpTex.zw -= Vectors; // Inverse warp in the [-0.5, 0.5) range
        WarpTex.zw = saturate(WarpTex.zw + 0.5); // Push and clamp into [0.0, 1.0) range

        // Get gradient information
        float4 TexIx = ddx(WarpTex);
        float4 TexIy = ddy(WarpTex);
        float2 PixelSize = abs(TexIx.xy) + abs(TexIy.xy);

        // Get required data to calculate Lucas-Kanade
        const int WindowSize = 3;
        const int WindowHalf = WindowSize / 2;
        const float Pi2 = CMath_GetPi() * 2.0;

        // Get stochastic sampling
        float Grid = Pi2 * CProcedural_GetGoldenHash(MainPos);
        float2 GridSinCos = 0.0;
        sincos(Grid, GridSinCos.y, GridSinCos.x);
        float2x2 RotationMatrix = float2x2(GridSinCos.x, GridSinCos.y, -GridSinCos.y, GridSinCos.x);

        [loop] for (int i = 0; i < (WindowSize * WindowSize); i++)
        {
            float2 Kernel = float2(i % WindowSize, i / WindowSize) - WindowHalf;
            Kernel = mul(Kernel, RotationMatrix);

            // Get temporal gradient
            float4 TexIT = WarpTex.xyzw + (Kernel.xyxy * PixelSize.xyxy);
            float3 T = tex2Dgrad(SampleT, TexIT.xy, TexIx.xy, TexIy.xy).xyz;
            float3 I = tex2Dgrad(SampleI, TexIT.zw, TexIx.zw, TexIy.zw).xyz;
            float3 IT = I - T;

            // Get spatial gradient
            float4 OffsetNS = Kernel.xyxy + float4(0.0, -1.0, 0.0, 1.0);
            float4 OffsetEW = Kernel.xyxy + float4(-1.0, 0.0, 1.0, 0.0);
            float4 NS = WarpTex.xyxy + (OffsetNS * PixelSize.xyxy);
            float4 EW = WarpTex.xyxy + (OffsetEW * PixelSize.xyxy);
            float3 N = tex2Dgrad(SampleT, NS.xy, TexIx.xy, TexIy.xy).xyz;
            float3 S = tex2Dgrad(SampleT, NS.zw, TexIx.xy, TexIy.xy).xyz;
            float3 E = tex2Dgrad(SampleT, EW.xy, TexIx.xy, TexIy.xy).xyz;
            float3 W = tex2Dgrad(SampleT, EW.zw, TexIx.xy, TexIy.xy).xyz;
            float3 Ix = E - W;
            float3 Iy = N - S;

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
        */

        // Construct matrices
        float2x2 A = float2x2(IxIx, IxIy, IxIy, IyIy);
        float2 B = float2(IxIt, IyIt);

        // Calculate C factor
        float N = dot(B, B);
        float2 DotBA = float2(dot(B, A[0]), dot(B, A[1]));
        float D = dot(DotBA, B);
        float C = N / D;

        // Calculate -C*B
        float2 Flow = (abs(D) > 0.0) ? -mul(C, B) : 0.0;

        // Normalize motion vectors
        Flow *= PixelSize;

        // Propagate normalized motion vectors in Norm Range
        Vectors += Flow;

        // Clamp motion vectors to restrict range to valid lengths
        Vectors = clamp(Vectors, -1.0, 1.0);

        // Encode motion vectors to FP16 format
        return CMath_Float2_NormToFP16(Vectors);
    }

#endif
