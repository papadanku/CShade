
/*
    This header file provides functions for real-time motion estimation, primarily utilizing the Lucas-Kanade optical flow algorithm. It includes utilities for sparse pyramid upsampling, calculating motion vectors between frames, and encoding/decoding these vectors to a specific FLT16 format. Additionally, it offers debug visualization functions to display motion vector direction, magnitude, and quadrant information. This file is crucial for implementing motion-dependent effects such as motion blur, motion stabilization, or datamoshing.
*/

#include "cBlur.fxh"
#include "cMath.fxh"

#if !defined(INCLUDE_CMOTIONESTIMATION)
    #define INCLUDE_CMOTIONESTIMATION

    /*
        Dilate up to 2^4 pixels.
        - Subsequent levels and the post-filter upsampling will address the undersampled regions.
        - This idea is based off depth-of-field undersampling and using a post-filter on the undersampled regions.
    */
    float2 CMotionEstimation_GetSparsePyramidUpsample(float2 HPos, float2 Tex, float2 PixelSize, sampler2D SampleSource)
    {
        // Constants (Math)
        float Pi = CMath_GetPi();
        float Pi2 = Pi * 2.0;
        float GoldenAngle = CMath_GetGoldenRatio();

        // Constants (Sum)
        const float Spread = exp2(3.0) * 2.0;
        const int SampleCount = 9;
        const float Weight = 1.0 / SampleCount;
        float R[SampleCount];

        [unroll]
        for (int i0 = 0; i0 < SampleCount; i0++)
        {
            // Compute radius fraction based on the tap index (sqrt ensures uniform area distribution)
            R[i0] = sqrt((float(i0) + 0.5) / float(SampleCount)) * Spread;
        }

        // Create a sequence of random numbers
        float IGN = CMath_GetInterleavedGradientNoise(HPos) * Pi2;

        // Initialize variables
        float2 Sum = 0.0;

        [unroll]
        for (int i1 = 0; i1 < SampleCount; i1++)
        {
            // Compute angle based on golden spiral + our per-pixel random dither rotation
            float Theta = (float(i1) * GoldenAngle) + IGN;

            // Convert polar coordinates to Cartesian offset vectors
            float2 DiskOffset;
            sincos(Theta, DiskOffset.y, DiskOffset.x);

            // Scale the offset by your search footprint converted to UV space
            DiskOffset *= R[i1];
            DiskOffset = Tex + (DiskOffset * PixelSize);

            // Gather the low-res motion vector baseline
            Sum += (tex2D(SampleSource, DiskOffset).xy * Weight);
        }

        return Sum;
    }

    /*
        Lucas-Kanade optical flow with bilinear fetches. The algorithm is motified to not output in pixels, but normalized displacements.

        ---

        Gauss-Newton Steepest Descent Inverse Additive Algorithm

        Baker, S., & Matthews, I. (2004). Lucas-kanade 20 years on: A unifying framework. International journal of computer vision, 56, 221-255.

        https://www.researchgate.net/publication/248602429_Lucas-Kanade_20_Years_On_A_Unifying_Framework_Part_1_The_Quantity_Approximated_the_Warp_Update_Rule_and_the_Gradient_Descent_Approximation

        ---

        Application of Lucas–Kanade algorithm with weight coefficient bilateral filtration for the digital image correlation method

        Titkov, V. V., Panin, S. V., Lyubutin, P. S., Chemezov, V. O., & Eremin, A. V. (2017). Application of Lucas–Kanade algorithm with weight coefficient bilateral filtration for the digital image correlation method. IOP Conference Series: Materials Science and Engineering, 177, 012039. https://doi.org/10.1088/1757-899X/177/1/012039
    */

    float3 CMotionEstimation_SRGBtoORGB(sampler2D Image, float2 Tex)
    {
        float3 Color = tex2D(Image, Tex).rgb;
        Color = CColor_SRGBtoYUV444(Color, false);
        return Color;
    }

    float2 CMotionEstimation_GetLucasKanade(
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

                (4, 0) (4, 1) (4, 2) (4, 3) (4, 4)
                (3, 0) (3, 1) (3, 2) (3, 3) (3, 4)
                (2, 0) (2, 1) (2, 2) (2, 3) (2, 4)
                (1, 0) (1, 1) (1, 2) (1, 3) (1, 4)
                (0, 0) (0, 1) (0, 2) (0, 3) (0, 4)
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
            int4(int2(-1, -1), int2(1, 1)),
            int4(int2(0, -1), int2(2, 1)),
            int4(int2(1, -1), int2(3, 1)),
            int4(int2(-1, 0), int2(1, 2)),
            int4(int2(0, 0), int2(2, 2)),
            int4(int2(1, 0), int2(3, 2)),
            int4(int2(-1, 1), int2(1, 3)),
            int4(int2(0, 1), int2(2, 3)),
            int4(int2(1, 1), int2(3, 3))
        };

        const float3 SWeights = exp2(-float3(0.0, 1.0, 2.0));

        // Decode from FLT16
        Vectors = clamp(CMath_FLT16toSNORM_FLT2(Vectors), -1.0, 1.0);

        // Calculate warped texture coordinates & gradient information
        float2 WarpTex = 0.0;
        WarpTex = MainTex - 0.5; // Pull into [-0.5, 0.5) range
        WarpTex -= Vectors; // Inverse warp in the [-0.5, 0.5) range
        WarpTex = saturate(WarpTex + 0.5); // Push and clamp into [0.0, 1.0) range

        // Create Cache
        // This unrolled version samples and assigns to the Cache array.
        // The four corners of the 5x5 grid are skipped in the original code,
        // so they are not included in this rewrite.
        Cache[1] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-1, -2) * PixelSize));
        Cache[2] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(0, -2) * PixelSize));
        Cache[3] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(1, -2) * PixelSize));

        Cache[5] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-2, -1) * PixelSize));
        Cache[6] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-1, -1) * PixelSize));
        Cache[7] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(0, -1) * PixelSize));
        Cache[8] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(1, -1) * PixelSize));
        Cache[9] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(2, -1) * PixelSize));

        Cache[10] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-2, 0) * PixelSize));
        Cache[11] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-1, 0) * PixelSize));
        Cache[12] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(0, 0) * PixelSize));
        Cache[13] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(1, 0) * PixelSize));
        Cache[14] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(2, 0) * PixelSize));

        Cache[15] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-2, 1) * PixelSize));
        Cache[16] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-1, 1) * PixelSize));
        Cache[17] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(0, 1) * PixelSize));
        Cache[18] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(1, 1) * PixelSize));
        Cache[19] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(2, 1) * PixelSize));

        Cache[21] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(-1, 2) * PixelSize));
        Cache[22] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(0, 2) * PixelSize));
        Cache[23] = CMotionEstimation_SRGBtoORGB(SampleT, MainTex + (float2(1, 2) * PixelSize));

        // Initialize variables
        float IxIx = 0.0;
        float IyIy = 0.0;
        float IxIy = 0.0;
        float IxIt = 0.0;
        float IyIt = 0.0;
        float WSum = 0.0;

        // Get center textures (this is for the spatial weighting)
        float3 CenterT = Cache[CMath_Get1DIndexFrom2D(int2(2, 2), CacheWidth)];
        float3 CenterI = CMotionEstimation_SRGBtoORGB(SampleI, WarpTex);

        [unroll]
        for (int i = 0; i < FetchGridSize; i++)
        {
            // Get cached data
            float3 North = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(0, -1), CacheWidth)];
            float3 South = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(0, 1), CacheWidth)];
            float3 East = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(1, 0), CacheWidth)];
            float3 West = Cache[CMath_Get1DIndexFrom2D(P[i].zw + int2(-1, 0), CacheWidth)];
            float3 R0 = Cache[CMath_Get1DIndexFrom2D(P[i].zw, CacheWidth)];

            // Get R0 and R1 to calculate temporal gradient
            bool IsCenter = (P[i].x == 0) && (P[i].y == 0);
            int OffsetID = abs(P[i].x) + abs(P[i].y);
            float2 Offset = float2(P[i].xy);

            // Get dynamic data
            float2 R1Tex = WarpTex + (Offset * PixelSize);
            float3 R1 = IsCenter ? CenterI : CMotionEstimation_SRGBtoORGB(SampleI, R1Tex);
            float3 It = 0.0;

            // Calculate bilateral weighting
            float Weight = 1.0;

            // Calculate range weights
            if (!IsCenter)
            {
                It = R0 - CenterT;
                Weight += dot(It, It);
                It = R1 - CenterI;
                Weight += dot(It, It);
                Weight = 1.0 / Weight;
                Weight *= Weight;
            }

            // Accumulate weight
            WSum += (Weight * SWeights[OffsetID]);

            // Immediately calculate spatial gradients
            float3 Ix = (West * 0.5) - (East * 0.5);
            float3 Iy = (North * 0.5) - (South * 0.5);
            It = R1 - R0;

            // Summate the weighted contributions
            IxIx += (dot(Ix, Ix) * Weight);
            IxIt += (dot(Ix, It) * Weight);
            IyIy += (dot(Iy, Iy) * Weight);
            IyIt += (dot(Iy, It) * Weight);
            IxIy += (dot(Ix, Iy) * Weight);
        }

        // Check if WSum is not 0
        WSum = (WSum > 0.0) ? 1.0 / WSum : 0.0;

        // Normalized weighted variables
        IxIx *= WSum;
        IyIy *= WSum;
        IxIy *= WSum;
        IxIt *= WSum;
        IyIt *= WSum;

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] = [-IxIt]
            [-IxIy/D  Iy^2/D]   [-IyIt]
        */

        float2x2 A = float2x2(IxIx, IxIy, IxIy, IyIy);
        float2 B = float2(IxIt, IyIt);

        // Calculate C factor
        float2 E = -B;
        float N = dot(E, E);
        float D = dot(E, mul(A, E));
        float C = N / D;

        // Calculate -C * B
        float2 Flow = (abs(D) > 0.0) ? -C * B : 0.0;

        // Normalize motion vectors
        Flow *= PixelSize;

        // Propagate normalized motion vectors in Norm Range
        Vectors += Flow;

        // Clamp motion vectors to restrict range to valid lengths
        Vectors = clamp(Vectors, -1.0, 1.0);

        // Encode motion vectors to FLT16 format
        return CMath_SNORMtoFLT16_FLT2(Vectors);
    }

    float3 CMotionEstimation_GetMotionVectorRGB(float2 MotionVectors)
    {
        float3 VectorRGB = normalize(float3(MotionVectors, 1e-3));
        VectorRGB.xy = CMath_SNORMtoUNORM_FLT2(VectorRGB.xy);
        VectorRGB.z = sqrt(1.0 - saturate(dot(VectorRGB.xy, VectorRGB.xy)));
        VectorRGB = normalize(VectorRGB);
        return VectorRGB;
    }

    float3 CMotionEstimation_GetDebugQuadrant(
        float3 Base,
        float3 ShaderOutput,
        float2 MotionVectors,
        float Index
    )
    {
        // First, process motion vectors
        float VectorMag = length(MotionVectors);
        float3 VectorRGB = CMotionEstimation_GetMotionVectorRGB(MotionVectors);

        float3 OutputColor = Base;
        OutputColor = lerp(OutputColor, VectorRGB, Index == 1);
        OutputColor = lerp(OutputColor, ShaderOutput, Index == 2);
        OutputColor = lerp(OutputColor, VectorMag, Index == 3);

        return OutputColor;
    }

#endif
