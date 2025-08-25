
#include "cBlur.fxh"
#include "cShade.fxh"
#include "cMath.fxh"

#if !defined(INCLUDE_CMOTIONESTIMATION)
    #define INCLUDE_CMOTIONESTIMATION

    /*
        Dilate up to 2^4 pixels.
        - Subsequent levels and the post-filter upsampling will address the undersampled regions.
        - This idea is based off depth-of-field undersampling and using a post-filter on the undersampled regions.
    */
    float4 CMotionEstimation_GetSparsePyramidUpsample(float2 Pos, float2 Tex, sampler2D SampleSource)
    {
        float SparseFactor = 4.0;
        float Pi2 = CMath_GetPi() * 2.0;
        float2 Delta = ldexp(fwidth(Tex), SparseFactor);

        float4 Sum = 0.0;
        float Weight = 0.0;

        [unroll]
        for (float x = -0.75; x <= 0.75; x += 0.5)
        {
            [unroll]
            for (float y = -0.75; y <= 0.75; y += 0.5)
            {
                float2 Shift = float2(float(x), float(y));
                float2 DiskShift = CMath_MapUVtoConcentricDisk(Shift);

                float2 FetchTex = Tex + (DiskShift * Delta);
                Sum += tex2D(SampleSource, FetchTex);
                Weight += 1.0;
            }
        }

        return Sum / Weight;
    }

    /*
        Lucas-Kanade optical flow with bilinear fetches. The algorithm is motified to not output in pixels, but normalized displacements.

        ---

        Gauss-Newton Steepest Descent Inverse Additive Algorithm

        Baker, S., & Matthews, I. (2004). Lucas-kanade 20 years on: A unifying framework. International journal of computer vision, 56, 221-255.

        https://www.researchgate.net/publication/248602429_Lucas-Kanade_20_Years_On_A_Unifying_Framework_Part_1_The_Quantity_Approximated_the_Warp_Update_Rule_and_the_Gradient_Descent_Approximation
    */

    float2 CMotionEstimation_GetPixelPyLK(
        bool IsCoarse,
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
        float SumWeight = 0.0;

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

        // Initiate TemplateCache
        const int TemplateGridSize = 5;
        const int TemplateCacheSize = TemplateGridSize * TemplateGridSize;
        float3 TemplateCache[TemplateCacheSize];

        // Create TemplateCache
        int TemplateCacheIndex = 0;
        [unroll]
        for (int y1 = 2; y1 >= -2; y1--)
        {
            [unroll]
            for (int x1 = -2; x1 <= 2; x1++)
            {
                bool OutOfBounds = (abs(x1) == 2) && (abs(y1) == 2);
                float2 Tex = MainTex + (float2(x1, y1) * PixelSize);
                TemplateCache[TemplateCacheIndex] = OutOfBounds ? 0.0 : tex2D(SampleT, Tex).xyz;
                TemplateCacheIndex += 1;
            }
        }

        // Loop over the starred template areas
        const int FetchGridWidth = 3;
        const int FetchGridSize = FetchGridWidth * FetchGridWidth;
        int FetchGridIndex = 0;

        const int2 TemplateGridPos[FetchGridSize] =
        {
            int2(3, 1), int2(3, 2), int2(3, 3),
            int2(2, 1), int2(2, 2), int2(2, 3),
            int2(1, 1), int2(1, 2), int2(1, 3)
        };

        const int2 FetchPos[FetchGridSize] =
        {
            int2(-1, -1), int2(0, -1), int2(1, -1),
            int2(-1, 0), int2(0, 0), int2(1, 0),
            int2(-1, 1), int2(0, 1), int2(1, 1)
        };

        // Get center textures (this is for the spatial weighting)
        float3 CenterT = TemplateCache[CMath_Get1DIndexFrom2D(int2(2, 2), TemplateGridSize)];
        float3 CenterI = tex2D(SampleI, WarpTex).xyz;

        [unroll]
        for (int i = 0; i < FetchGridSize; i++)
        {
            int2 P = FetchPos[i];
            int2 GridPos = TemplateGridPos[FetchGridIndex];

            // Calculate temporal gradient
            bool Cached = (P.x == 0) && (P.y == 0);
            float3 I = Cached ? CenterI : tex2D(SampleI, WarpTex + (float2(P) * PixelSize)).xyz;
            float3 T = Cached ? CenterT : TemplateCache[CMath_Get1DIndexFrom2D(GridPos, TemplateGridSize)];

            // Calculate spatial and temporal gradients
            float3 North = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(1, 0), TemplateGridSize)];
            float3 South = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(-1, 0), TemplateGridSize)];
            float3 East = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(0, 1), TemplateGridSize)];
            float3 West = TemplateCache[CMath_Get1DIndexFrom2D(GridPos + int2(0, -1), TemplateGridSize)];
            float3 Ix = (West - East) / 2.0;
            float3 Iy = (North - South) / 2.0;
            float3 It = I - T;

            // Calculate weight
            float3 DeltaT = T - CenterT;
            float3 DeltaI = I - CenterI;
            float Dot4 = rsqrt(dot(DeltaT, DeltaT) + dot(DeltaI, DeltaI) + 1.0);
            float Weight = smoothstep(0.0, 1.0, Dot4);
            Weight *= Weight;

            // IxIx = A11; IyIy = A22; IxIy = A12/A22
            IxIx += dot(Ix, Ix) * Weight;
            IyIy += dot(Iy, Iy) * Weight;
            IxIy += dot(Ix, Iy) * Weight;

            // IxIt = B1; IyIt = B2
            IxIt += dot(Ix, It) * Weight;
            IyIt += dot(Iy, It) * Weight;

            // Summate the weights
            SumWeight += Weight;

            // Increment TemplatePos
            FetchGridIndex += 1;
        }

        // Check if SumWeight isn't 0;
        SumWeight = (SumWeight == 0.0) ? 0.0 : 1.0 / SumWeight;
        IxIx *= SumWeight;
        IyIy *= SumWeight;
        IxIy *= SumWeight;
        IxIt *= SumWeight;
        IyIt *= SumWeight;

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

        // Encode motion vectors to FP16 format
        return CMath_Float2_NormToFP16(Vectors);
    }

#endif
