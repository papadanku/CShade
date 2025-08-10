
#include "cBlur.fxh"
#include "cShade.fxh"
#include "cMath.fxh"

#if !defined(INCLUDE_CMOTIONESTIMATION)
    #define INCLUDE_CMOTIONESTIMATION

    /*
        Dilate up to 2^2 pixels.
        - Subsequent levels and the post-filter upsampling will address the undersampled regions.
        - This idea is based off depth-of-field undersampling and using a post-filter on the undersampled regions.
    */
    float4 CMotionEstimation_GetSparsePyramidUpsample(sampler2D SampleSource, float2 Tex)
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

    float2 CMotionEstimation_GetPixelPyLK(
        float2 MainPos,
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleT,
        sampler2D SampleI
    )
    {
        // Initialize variables
        float IxIx = 0.0;
        float IyIy = 0.0;
        float IxIy = 0.0;
        float IxIt = 0.0;
        float IyIt = 0.0;

        // Decode from FP16
        Vectors = clamp(CMath_Float2_FP16ToNorm(Vectors), -1.0, 1.0);

        // Calculate warped texture coordinates
        float2 WarpTex = MainTex;
        WarpTex -= 0.5; // Pull into [-0.5, 0.5) range
        WarpTex -= Vectors; // Inverse warp in the [-0.5, 0.5) range
        WarpTex = saturate(WarpTex + 0.5); // Push and clamp into [0.0, 1.0) range

        // Get gradient information
        float2 PixelSize = fwidth(MainTex);

        /*
            Template indecies:

                * = Indecies for calculating the temporal gradient (IT)
                - = Unused indecies

                00- 01  02  03  04-
                05  06* 07* 08* 09
                10  11* 12* 13* 14
                15  16* 17* 18* 19
                20- 21  22  23  24-

            Template (Row, Column):

                (0, 0) (0, 1) (0, 2) (0, 3) (0, 4)
                (1, 0) (1, 1) (1, 2) (1, 3) (1, 4)
                (2, 0) (2, 1) (2, 2) (2, 3) (2, 4)
                (3, 0) (3, 1) (3, 2) (3, 3) (3, 4)
                (4, 0) (4, 1) (4, 2) (4, 3) (4, 4)
        */

        // Initiate TemplateCache
        const int TemplateGridSize = 5;
        const int TemplateCacheSize = TemplateGridSize * TemplateGridSize;
        float3 TemplateCache[TemplateCacheSize];

        // Create TemplateCache
        int TemplateCacheIndex = 0;
        [unroll] for (int y1 = 2; y1 >= -2; y1--)
        {
            [unroll] for (int x1 = 2; x1 >= -2; x1--)
            {
                bool OutOfBounds = (abs(x1) == 2) && (abs(y1) == 2);
                float2 Tex = MainTex + (float2(x1, y1) * PixelSize);
                TemplateCache[TemplateCacheIndex] = OutOfBounds ? 0.0 : tex2D(SampleT, Tex).xyz;
                TemplateCacheIndex += 1;
            }
        }

        // Loop over the starred template areas
        int TemplateGridPosIndex = 0;
        int2 TemplateGridPos[9] =
        {
            int2(1, 1), int2(1, 2), int2(1, 3),
            int2(2, 1), int2(2, 2), int2(2, 3),
            int2(3, 1), int2(3, 2), int2(3, 3),
        };

        [unroll] for (int y2 = 1; y2 >= -1; y2--)
        {
            [unroll] for (int x2 = 1; x2 >= -1; x2--)
            {
                int2 GridPos = TemplateGridPos[TemplateGridPosIndex];

                // Calculate temporal gradient
                float3 I = tex2D(SampleI, WarpTex + (float2(x2, y2) * PixelSize)).xyz;
                float3 T = TemplateCache[CMath_Get1DIndexFrom2D(GridPos, TemplateGridSize)];
                float3 It = I - T;

                // Calculate spatial gradients with central difference operator
                float3 N = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(1, 0), TemplateGridSize)];
                float3 S = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(-1, 0), TemplateGridSize)];
                float3 E = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(0, -1), TemplateGridSize)];
                float3 W = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(0, 1), TemplateGridSize)];
                float3 Ix = (W - E) / 2.0;
                float3 Iy = (N - S) / 2.0;

                // IxIx = A11; IyIy = A22; IxIy = A12/A22
                IxIx += dot(Ix, Ix);
                IyIy += dot(Iy, Iy);
                IxIy += dot(Ix, Iy);

                // IxIt = B1; IyIt = B2
                IxIt += dot(Ix, It);
                IyIt += dot(Iy, It);

                // Increment TemplatePos
                TemplateGridPosIndex += 1;
            }
        }

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] [-IxIt]
            [-IxIy/D  Iy^2/D] [-IyIt]
        */

        // Calculate multiplications here
        float IxItIxIt = IxIt * IxIt;
        float IxItIyIt = IxIt * IyIt;
        float IyItIyIt = IyIt * IyIt;

        // Calculate C factor
        float2x2 A = float2x2(IxIx, IxIy, IxIy, IyIy);
        float2 B = float2(IxIt, IyIt);
        float2x2 N = float2x2(IxItIxIt, IxItIyIt, IxItIyIt, IyItIyIt);
        float D = 1.0 / dot(mul(-B, A), -B);
        float2x2 C = N * D;

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
