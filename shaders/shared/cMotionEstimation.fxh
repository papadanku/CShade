
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

        ---

        Application of Lucas–Kanade algorithm with weight coefficient bilateral filtration for the digital image correlation method

        Titkov, V. V., Panin, S. V., Lyubutin, P. S., Chemezov, V. O., & Eremin, A. V. (2017). Application of Lucas–Kanade algorithm with weight coefficient bilateral filtration for the digital image correlation method. IOP Conference Series: Materials Science and Engineering, 177, 012039. https://doi.org/10.1088/1757-899X/177/1/012039
    */

    float2 CMotionEstimation_GetLucasKanade(
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
        float SumW = 0.0;

        // Decode from FLT16
        Vectors = clamp(CMath_FLT16toSNORM_FLT2(Vectors), -1.0, 1.0);

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
                [flatten]
                if ((abs(x1) == 2) && (abs(y1) == 2))
                {
                    TemplateCacheIndex += 1;
                }
                else
                {
                    float2 Tex = MainTex + (float2(x1, y1) * PixelSize);
                    TemplateCache[TemplateCacheIndex] = tex2D(SampleT, Tex).xyz;
                    TemplateCacheIndex += 1;
                }
            }
        }

        // Loop over the starred template areas
        const int FetchGridWidth = 3;
        const int FetchGridSize = FetchGridWidth * FetchGridWidth;

        // .xy = TemplateGridPos; .zw = FetchPos
        const int4 P[FetchGridSize] =
        {
            int4(int2(-1, -1), int2(3, 1)),
            int4(int2(0, -1), int2(3, 2)),
            int4(int2(1, -1), int2(3, 3)),
            int4(int2(-1, 0), int2(2, 1)),
            int4(int2(0, 0), int2(2, 2)),
            int4(int2(1, 0), int2(2, 3)),
            int4(int2(-1, 1), int2(1, 1)),
            int4(int2(0, 1), int2(1, 2)),
            int4(int2(1, 1), int2(1, 3))
        };

        // Get center textures (this is for the spatial weighting)
        float3 CenterT = TemplateCache[CMath_Get1DIndexFrom2D(int2(2, 2), TemplateGridSize)];
        float3 CenterI = tex2D(SampleI, WarpTex).xyz;

        [unroll]
        for (int i = 0; i < FetchGridSize; i++)
        {
            bool Cached = (P[i].x == 0) && (P[i].y == 0);

            // Calculate temporal gradient
            float3 R0 = Cached ? CenterT : TemplateCache[CMath_Get1DIndexFrom2D(P[i].zw, TemplateGridSize)];
            float3 R1 = Cached ? CenterI : tex2D(SampleI, WarpTex + (float2(P[i].xy) * PixelSize)).xyz;
            float3 It = R1 - R0;

            // Calculate weight
            R0 -= CenterT;
            R1 -= CenterI;
            R0.x = dot(R0, R0);
            R0.y = dot(R1, R1);
            R0.z = 1.0;
            float Weight = rsqrt(dot(R0, 1.0));
            Weight = smoothstep(0.0, 1.0, Weight);
            Weight *= Weight;

            // Calculate spatial and temporal gradients
            float3 North = TemplateCache[CMath_Get1DIndexFrom2D(P[i].zw + int2(1, 0), TemplateGridSize)];
            float3 South = TemplateCache[CMath_Get1DIndexFrom2D(P[i].zw + int2(-1, 0), TemplateGridSize)];
            float3 East = TemplateCache[CMath_Get1DIndexFrom2D(P[i].zw + int2(0, 1), TemplateGridSize)];
            float3 West = TemplateCache[CMath_Get1DIndexFrom2D(P[i].zw + int2(0, -1), TemplateGridSize)];

            // IxIx = A11; IxIt = B1
            R0 = (West * 0.5) - (East * 0.5);
            IxIx += (dot(R0, R0) * Weight);
            IxIt += (dot(R0, It) * Weight);

            // IyIy = A22; IyIt = B2
            R1 = (North * 0.5) - (South * 0.5);
            IyIy += (dot(R1, R1) * Weight);
            IyIt += (dot(R1, It) * Weight);

            // A12/A22
            IxIy += (dot(R0, R1) * Weight);

            // Summate the weights
            SumW += Weight;
        }

        // Check if SumW is not 0
        SumW = (SumW == 0.0) ? 0.0 : 1.0 / SumW;

        // Normalized weighted variables
        IxIx *= SumW;
        IyIy *= SumW;
        IxIy *= SumW;
        IxIt *= SumW;
        IyIt *= SumW;

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
        VectorRGB.xy = (VectorRGB.xy * 0.5) + 0.5;
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
