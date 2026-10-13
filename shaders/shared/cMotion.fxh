
/*
    This header file provides functions for real-time motion estimation, primarily utilizing the Lucas-Kanade optical flow algorithm. It includes utilities for sparse pyramid upsampling, calculating motion vectors between frames, and encoding/decoding these vectors to a specific FP16 format. Additionally, it offers debug visualization functions to display motion vector direction, magnitude, and quadrant information. This file is crucial for implementing motion-dependent effects such as motion blur, motion stabilization, or datamoshing.
*/

#include "cBlur.fxh"
#include "cMath.fxh"

#if !defined(INCLUDE_CMOTION)
    #define INCLUDE_CMOTION

    float3 CMotion_GetPyramids(sampler2D SampleSource, float2 Tex)
    {
        float3 ColorL = tex2Dlod(SampleSource, CShade_PadFloat2(Tex)).rgb;
        float3 ColorP = CColor_EncodeLogC(ColorL) / CColor_EncodeLogC(1.0);

        float ColorSumP = dot(ColorP, 1.0);
        float3 ColorRatioP = abs(ColorSumP) > 0.0 ? ColorP / ColorSumP : 1.0 / 3.0;
        float MaxColorRatioP = max(ColorRatioP.r, max(ColorRatioP.g, ColorRatioP.b));
        float MaxColorP = max(ColorP.r, max(ColorP.g, ColorP.b));

        float3 Output = 0.0;
        Output.xy = (ColorSumP > 0.0) ? ColorRatioP.xy / MaxColorRatioP : 1.0;
        Output.z = MaxColorP;

        return Output;
    }

    float2 CMotion_GetSparsePyramidUpsample(float2 HPos, float2 Tex, float2 PixelSize, sampler2D SampleSource)
    {
        /*
            Dilate up to 2^3 pixels.

            - Subsequent levels and the post-filter upsampling will address the undersampled regions.
            - This idea is based off depth-of-field undersampling and using a post-filter on the undersampled regions.
        */

        const float DilateScale = exp2(3.0);

        // Initialize Sum
        float2 Sum = 0.0;
        float Weight = 0.0;

        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            [unroll]
            for (int y = -1; y <= 1; y++)
            {
                float2 Shift = float2(x, y) * DilateScale;
                float2 FetchTex = Tex + (Shift * PixelSize);

                Sum += tex2Dlod(SampleSource, CShade_PadFloat2(FetchTex)).xy;
                Weight += 1.0;
            }
        }

        return Sum / Weight;
    }

    /*
        Lucas-Kanade optical flow with bilinear fetches. The algorithm is motified to not output in pixels, but normalized displacements.

        ---

        Baker, S., & Matthews, I. (2004). Lucas-kanade 20 years on: A unifying framework. International journal of computer vision, 56, 221-255.

        https://www.researchgate.net/publication/248602429_Lucas-Kanade_20_Years_On_A_Unifying_Framework_Part_1_The_Quantity_Approximated_the_Warp_Update_Rule_and_the_Gradient_Descent_Approximation

        ---

        Application of Lucas–Kanade algorithm with weight coefficient bilateral filtration for the digital image correlation method

        Titkov, V. V., Panin, S. V., Lyubutin, P. S., Chemezov, V. O., & Eremin, A. V. (2017). Application of Lucas–Kanade algorithm with weight coefficient bilateral filtration for the digital image correlation method. IOP Conference Series: Materials Science and Engineering, 177, 012039. https://doi.org/10.1088/1757-899X/177/1/012039
    */

    float CMotion_GetDiceIndex(
        float E,    // dot(T_r, T_r) + dot(I_r, I_r)
        float3 T_r, // T (Reference)
        float3 T_s, // T (Sample)
        float3 I_r, // I (Reference)
        float3 I_s  // I (Sample)
    )
    {
        float N = dot(T_r, T_s) + dot(I_r, I_s);
        float D = dot(T_s, T_s) + dot(I_s, I_s) + E;

        float S = (abs(D) > 0.0)
            ? saturate((N / D) + 0.5)
            : 1.0;

        return S;
    }

    float2 CMotion_GetLucasKanade(
        bool IsCoarse,
        float2 MainTex,
        float2 PixelSize,
        float2 Vectors,
        sampler2D SampleT,
        sampler2D SampleI
    )
    {
        /*
            * = Indecies for calculating the temporal gradient (IT)
            - = Unused indecies

            Template indecies:

                00- 01  02  03  04-
                05  06* 07* 08* 09
                10  11* 12* 13* 14
                15  16* 17* 18* 19
                20- 21  22  23  24-

            Template (Row, Column):

                (0, 0) (1, 0) (2, 0) (3, 0) (4, 0)
                (0, 1) (1, 1) (2, 1) (3, 1) (4, 1)
                (0, 2) (1, 2) (2, 2) (3, 2) (4, 2)
                (0, 3) (1, 3) (2, 3) (3, 3) (4, 3)
                (0, 4) (1, 4) (2, 4) (3, 4) (4, 4)
        */

        // Initiate Cache
        const int CacheWidth = 5;
        const int CacheIndexSize = CacheWidth * CacheWidth;
        float3 Cache[CacheIndexSize];

        // Loop over the starred template areas
        const int FetchGridWidth = 3;
        const int FetchGridSize = FetchGridWidth * FetchGridWidth;

        // .xy = TemplateGridPos; .zw = FetchPos
        const int4 P[FetchGridSize] =
        {
            // Process edge regions
            int4(int2(-1, -1), int2(1, 1)),
            int4(int2(1, -1), int2(3, 1)),
            int4(int2(-1, 1), int2(1, 3)),
            int4(int2(1, 1), int2(3, 3)),

            // Process cardinal regions
            int4(int2(0, -1), int2(2, 1)),
            int4(int2(-1, 0), int2(1, 2)),
            int4(int2(1, 0), int2(3, 2)),
            int4(int2(0, 1), int2(2, 3)),

            // Process center
            int4(int2(0, 0), int2(2, 2))
        };

        // Decode from FP16
        Vectors = clamp(CMath_FP16toSNORM_FLT2(Vectors), -1.0, 1.0);

        // Calculate warped texture coordinates & gradient information
        float2 WarpTex = 0.0;
        WarpTex = MainTex - 0.5; // Pull into [-0.5, 0.5) range
        WarpTex -= Vectors; // Inverse warp in the [-0.5, 0.5) range
        WarpTex = saturate(WarpTex + 0.5); // Push and clamp into [0.0, 1.0) range

        // Create Cache
        // This unrolled version samples and assigns to the Cache array.
        // The four corners of the 5x5 grid are skipped in the original code,
        // so they are not included in this rewrite.
        Cache[1] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-1, -2) * PixelSize))).xyz;
        Cache[2] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(0, -2) * PixelSize))).xyz;
        Cache[3] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(1, -2) * PixelSize))).xyz;

        Cache[5] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-2, -1) * PixelSize))).xyz;
        Cache[6] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-1, -1) * PixelSize))).xyz;
        Cache[7] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(0, -1) * PixelSize))).xyz;
        Cache[8] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(1, -1) * PixelSize))).xyz;
        Cache[9] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(2, -1) * PixelSize))).xyz;

        Cache[10] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-2, 0) * PixelSize))).xyz;
        Cache[11] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-1, 0) * PixelSize))).xyz;
        Cache[12] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(0, 0) * PixelSize))).xyz;
        Cache[13] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(1, 0) * PixelSize))).xyz;
        Cache[14] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(2, 0) * PixelSize))).xyz;

        Cache[15] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-2, 1) * PixelSize))).xyz;
        Cache[16] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-1, 1) * PixelSize))).xyz;
        Cache[17] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(0, 1) * PixelSize))).xyz;
        Cache[18] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(1, 1) * PixelSize))).xyz;
        Cache[19] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(2, 1) * PixelSize))).xyz;

        Cache[21] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(-1, 2) * PixelSize))).xyz;
        Cache[22] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(0, 2) * PixelSize))).xyz;
        Cache[23] = tex2Dlod(SampleT, CShade_PadFloat2(MainTex + (float2(1, 2) * PixelSize))).xyz;

        // Initialize variables
        float3 A = 0.0;
        float2 B = 0.0;
        float WSum = 0.0;

        // Get center textures (this is for the spatial weighting)
        float3 T_C = Cache[CMath_Get1DIndexFrom2D(int2(2, 2), CacheWidth)];
        float3 I_C = tex2Dlod(SampleI, CShade_PadFloat2(WarpTex)).xyz;

        // Get center magnitudes
        float TT_II = dot(T_C, T_C) + dot(I_C, I_C);

        [unroll]
        for (int i = 0; i < FetchGridSize; i++)
        {
            // Get cached data
            float3 T_N = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(0, -1), CacheWidth)];
            float3 T_S = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(0, 1), CacheWidth)];
            float3 T_E = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(1, 0), CacheWidth)];
            float3 T_W = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(-1, 0), CacheWidth)];
            float3 T = Cache[CMath_Get1DIndexFrom2D(P[i].zw, CacheWidth)];

            // Get dynamic data
            float2 UV = WarpTex + (float2(P[i].xy) * PixelSize);
            bool CenterFetch = (P[i].x == 0) && (P[i].y == 0);
            float3 I = CenterFetch
                ? I_C
                : tex2Dlod(SampleI, CShade_PadFloat2(UV)).xyz;

            // Calculate bilateral weighting
            float Weight = CenterFetch
                ? 1.0
                : CMotion_GetDiceIndex(TT_II, T_C, T, I_C, I);

            // Accumulate weight
            WSum += Weight;

            // Immediately calculate spatial gradients
            float3 Ix = (T_W - T_E) * 0.5;
            float3 Iy = (T_N - T_S) * 0.5;
            A[0] += (dot(Ix, Ix) * Weight);
            A[1] += (dot(Iy, Iy) * Weight);
            A[2] += (dot(Ix, Iy) * Weight);

            float3 It = I - T;
            B[0] += (dot(Ix, It) * Weight);
            B[1] += (dot(Iy, It) * Weight);
        }

        // Normalized weighted variables
        WSum = 1.0 / WSum;
        A *= WSum;
        B *= WSum;

        /*
            Calculate Lucas-Kanade matrix

            ---

            [ Ix^2/D -IxIy/D] [U] = [-IxIt]
            [-IxIy/D  Iy^2/D] [V]   [-IyIt]

            [A[0] A[2]] [U] = [-B[0]]
            [A[2] A[1]] [V]   [-B[1]]

            [U] = [ A[1] -A[2]] [-B[0]]
            [V]   [-A[2]  A[0]] [-B[1]]
        */

        /*
            ANISOTROPY FACTOR
            -----------------

            1. Mathematical Derivation:

                We start with the Normalized Anisotropy metric 'S' and the Trace-scaled
                damping factor 'Lambda':

                    S = 1.0 - (4.0 * Dt) / (Tr * Tr)
                    Lambda = Tr * S

                Substituting S into Lambda and applying the distributive property:

                    Lambda = Tr * (1.0 - (4.0 * Dt) / (Tr * Tr))
                    Lambda = Tr - (Tr * (4.0 * Dt) / (Tr * Tr))
                    Lambda = Tr - ((4.0 * Dt) / Tr)

            This algebraic simplification cancels out one 'Tr' term.

            2. Why We Scale by the Trace (Tr):

                Scaling Lambda by the Trace (total local gradient energy, Tr = Ix^2 + Iy^2) makes the damping factor scale-invariant / contrast-invariant.

                Is this very prevalent if you apply a constant to the diagonals, but the influences of A00 & A11 become too weak in low contrast areas (low gradients scale) and high contrast areas (high gradient scale)

                If image contrast changes by a factor 'c' (I' = c * I):

                    * Structure Tensor elements scale by c^2.
                    * Trace scales by c^2 (Tr' = c^2 * Tr).
                    * Determinant scales by c^4 (Dt' = c^4 * Dt).

                Without Trace-scaling (using a fixed static constant Lambda):

                    * High contrast: Lambda is too small for matrix inversion.
                    * Low contrast: Lambda dominates the matrix relative to the scale of the gradients.

                With Trace-scaling:

                    * Lambda' = c^2 * Lambda.
                    * Lambda grows and shrinks in exact 1:1 proportion with the Hessian's diagonal elements (A00, A11), preserving identical regularized flow vectors regardless of brightness or exposure changes.
        */

        float Tr = A[0] + A[1];
        float XY = A[2] * A[2];
        float Dt = (A[0] * A[1]) - XY;
        float Tr_Rcp = 1.0 / Tr;

        float Lambda = isinf(Tr_Rcp)
            ? 0.0
            : max(0.0, Tr - ((4.0 * Dt) * Tr_Rcp));

        // Regularized Hessian Diagonal
        float A00 = A[0] + Lambda;
        float A11 = A[1] + Lambda;

        // Invert Regularized Hessian
        float Dt_Rcp = 1.0 / ((A00 * A11) - XY);

        float2 Flow = float2(
            ( A11  * -B[0]) + (-A[2] * -B[1]),
            (-A[2] * -B[0]) + ( A00  * -B[1])
        );

        Flow = isinf(abs(Dt_Rcp))
            ? 0.0
            : Flow * Dt_Rcp;

        // Propagate normalized motion vectors in Norm Range
        Vectors += (Flow * PixelSize);

        // Clamp motion vectors to restrict range to valid lengths
        Vectors = clamp(Vectors, -1.0, 1.0);

        // Encode motion vectors to FP16 format
        return CMath_SNORMtoFP16_FLT2(Vectors);
    }

    float3 CMotion_GetMotionVectorRGB(float2 MotionVectors)
    {
        float3 VectorRGB = normalize(float3(MotionVectors, 1e-3));
        VectorRGB.xy = CMath_SNORMtoUNORM_FLT2(VectorRGB.xy);
        VectorRGB.z = sqrt(1.0 - saturate(dot(VectorRGB.xy, VectorRGB.xy)));
        VectorRGB = normalize(VectorRGB);
        return VectorRGB;
    }

    float3 CMotion_GetDebugQuadrant(
        float3 Base,
        float3 ShaderOutput,
        float2 MotionVectors,
        float Index
    )
    {
        // First, process motion vectors
        float VectorMag = length(MotionVectors);
        float3 VectorRGB = CMotion_GetMotionVectorRGB(MotionVectors);

        float3 OutputColor = Base;
        OutputColor = lerp(OutputColor, VectorRGB, Index == 1);
        OutputColor = lerp(OutputColor, ShaderOutput, Index == 2);
        OutputColor = lerp(OutputColor, VectorMag, Index == 3);

        return OutputColor;
    }

#endif
