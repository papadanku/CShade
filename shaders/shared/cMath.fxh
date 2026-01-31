
/*
    This header file provides a comprehensive library of mathematical functions and utilities essential for shader programming. It includes functions for common vector and scalar operations (min, max, median, modulus), conversions between normalized and signed-normalized ranges, and handling floating-point precision. The file also offers advanced features such as geometric transformations (scaling, rotation, translation) with configurable order, screen-space utilities (pixel size, grid generation), and various noise functions (hash-based, Golden Ratio, Interleaved Gradient, Value, and Gradient noise) for procedural generation and dithering. Additionally, it contains functions for encoding/decoding velocity vectors and mapping UV coordinates to a concentric disk.
*/

/*
    The MIT License (MIT)

    https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DoFMedianFilterCS.hlsl

    Copyright (c) 2015 Microsoft

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

#if !defined(INCLUDE_CMATH)
    #define INCLUDE_CMATH

    float4 CMath_Max3_FLT4(float4 A, float4 B, float4 C)
    {
        return max(max(A, B), C);
    }

    float4 CMath_Min3_FLT4(float4 A, float4 B, float4 C)
    {
        return min(min(A, B), C);
    }

    float4 CMath_Med3_FLT4(float4 x, float4 y, float4 z)
    {
        return max(min(x, y), min(max(x, y), z));
    }

    float CMath_Med3_FLT1(float x, float y, float z)
    {
        return max(min(x, y), min(max(x, y), z));
    }

    float4 CMath_Med9_FLT4(
        float4 X0, float4 X1, float4 X2,
        float4 X3, float4 X4, float4 X5,
        float4 X6, float4 X7, float4 X8)
    {
        float4 A = CMath_Max3_FLT4(CMath_Min3_FLT4(X0, X1, X2), CMath_Min3_FLT4(X3, X4, X5), CMath_Min3_FLT4(X6, X7, X8));
        float4 B = CMath_Min3_FLT4(CMath_Max3_FLT4(X0, X1, X2), CMath_Max3_FLT4(X3, X4, X5), CMath_Max3_FLT4(X6, X7, X8));
        float4 C = CMath_Med3_FLT4(CMath_Med3_FLT4(X0, X1, X2), CMath_Med3_FLT4(X3, X4, X5), CMath_Med3_FLT4(X6, X7, X8));
        return CMath_Med3_FLT4(A, B, C);
    }

    float CMath_GetModulus_FLT1(float X, float Y)
    {
        return X - Y * floor(X / Y);
    }

    float CMath_GetPi()
    {
        return acos(-1.0);
    }

    float CMath_GetNAN()
    {
        return 0.0 / 0.0;
    }

    bool CMath_GetOutOfBounds(float2 Tex)
    {
        return any(Tex < 0.0 || Tex > 1.0);
    }

    float2x2 CMath_GetRotationMatrix(float A)
    {
        return float2x2(cos(A), sin(A), -sin(A), cos(A));
    }

    int CMath_GetFactorial(int N)
    {
        int O = N;
        for (int i = 1 ; i < N; i++)
        {
            O *= i;
        }
        return O;
    }

    float CMath_UNORMtoSNORM_FLT1(float X)
    {
        return (X * 2.0) - 1.0;
    }

    float2 CMath_UNORMtoSNORM_FLT2(float2 X)
    {
        return (X * 2.0) - 1.0;
    }

    float3 CMath_UNORMtoSNORM_FLT3(float3 X)
    {
        return (X * 2.0) - 1.0;
    }

    float4 CMath_UNORMtoSNORM_FLT4(float4 X)
    {
        return (X * 2.0) - 1.0;
    }

    float CMath_SNORMtoUNORM_FLT1(float X)
    {
        return (X * 0.5) + 0.5;
    }

    float2 CMath_SNORMtoUNORM_FLT2(float2 X)
    {
        return (X * 0.5) + 0.5;
    }

    float3 CMath_SNORMtoUNORM_FLT3(float3 X)
    {
        return (X * 0.5) + 0.5;
    }

    float4 CMath_SNORMtoUNORM_FLT4(float4 X)
    {
        return (X * 0.5) + 0.5;
    }

    /*
        Function to convert 2D row and column (0-indexed) to a 1D index.
        ZeroIndexGridPos.x: The 0-indexed row number.
        ZeroIndexGridPos.y: The 0-indexed column number.
        GridWidth: The total width of the grid (number of columns).
        Returns a 1D index.
    */
    int CMath_Get1DIndexFrom2D(int2 ZeroIndexGridPos, int GridWidth)
    {
        return (ZeroIndexGridPos.x * GridWidth) + ZeroIndexGridPos.y;
    }

    // Get the Half format distribution of bits
    // Sign Exponent Significand
    // x    xxxxx    xxxxxxxxxx
    float CMath_CalculateFLT16(int Sign, int Exponent, int Significand)
    {
        const int Bias = -15;
        const int MaxExponent = (Exponent - exp2(1)) + Bias;
        const int MaxSignificand = 1 + ((Significand - 1) / Significand);

        return (float)pow(-1, Sign) * (float)exp2(MaxExponent) * (float)MaxSignificand;
    }

    float CMath_GetFLT16Min()
    {
        /*
            Sign Exponent Significand
            ---- -------- -----------
            0    00001    000000000
        */
        return CMath_CalculateFLT16(0, exp2(1) + 1, exp2(0));
    }

    float CMath_GetFLT16Max()
    {
        /*
            Sign Exponent Significand
            ---- -------- -----------
            0    11110    1111111111
        */
        return CMath_CalculateFLT16(0, exp2(5), exp2(10));
    }

    // [-HalfMax, HalfMax) -> [-1.0, 1.0)
    float2 CMath_FLT16toSNORM_FLT2(float2 Value)
    {
        return Value / CMath_GetFLT16Max();
    }

    float4 CMath_FLT16toSNORM_FLT4(float4 Value)
    {
        return Value / CMath_GetFLT16Max();
    }

    // [-1.0, 1.0) -> [-HalfMax, HalfMax)
    float2 CMath_SNORMtoFLT16_FLT2(float2 Value)
    {
        return Value * CMath_GetFLT16Max();
    }

    float4 CMath_SNORMtoFLT16_FLT4(float4 Value)
    {
        return Value * CMath_GetFLT16Max();
    }

    float2 CMath_CartesianToPolar(float2 Cartesian)
    {
        // r = magnitude of the vector
        float R = length(Cartesian);

        // Theta = angle in radians (-PI to PI)
        float Theta = atan2(Cartesian.y, Cartesian.x);

        return float2(R, Theta);
    }

    float3 CMath_CartesianToSpherical(float3 Cartesian)
    {
        // Precalculate (x*x + y*y)^0.5 and (x*x + y*y + z*z)^0.5
        float L1 = rsqrt(dot(Cartesian.xyz, Cartesian.xyz));
        float L2 = rsqrt(dot(Cartesian.xy, Cartesian.xy));

        // .x = radius; .y = inclination; .z = azimuth
        float3 RIA = 0.0;
        RIA.x = L1;
        RIA.y = Cartesian.z * L1;
        RIA.z = Cartesian.x * L2;

        // Calculate inclination and azimuth
        RIA.yz = acos(RIA.yz);

        return RIA;
    }

    void CMath_ApplyGeometricTransform(
        inout float2 Tex, // [0, 1)
        in int Order,
        in float Angle,
        in float2 Translate,
        in float2 Scale,
        bool ProcessTex
    )
    {
        /*
            The array containing the permutations of the geometric transforms.
            0 = Scale, 1 = Rotate, 2 = Translate
            The index of this array is driven by the _GeometricTransformOrder uniform.
            To get the correct permutation, you would access this array like:
            int3 Order = TransformPermutations[_GeometricTransformOrder];
        */
        const int3 TransformPermutations[6] =
        {
            int3(0, 1, 2),  // Scale > Rotate > Translate
            int3(0, 2, 1),  // Scale > Translate > Rotate
            int3(1, 0, 2),  // Rotate > Scale > Translate
            int3(1, 2, 0),  // Rotate > Translate > Scale
            int3(2, 0, 1),  // Translate > Scale > Rotate
            int3(2, 1, 0)   // Translate > Rotate > Scale
        };

        float Pi2 = CMath_GetPi() * 2.0;
        int3 Transforms = TransformPermutations[Order];

        // Rotations matrix
        float2x2 RotationMatrix = CMath_GetRotationMatrix(Angle * Pi2);

        // Translation matrix
        float3x3 TranslationMatrix = float3x3
        (
            1.0, 0.0, 0.0, // Row 1
            0.0, 1.0, 0.0, // Row 2
            Translate.x, Translate.y, 1.0 // Row 3
        );

        // Scaling matrix
        float2x2 ScalingMatrix = float2x2
        (
            Scale.x, 0.0, // Row 1
            0.0, Scale.y // Row 2
        );

        // Scale TexCoord from [0,1) to [-1,1)
        if (ProcessTex)
        {
            Tex = CMath_UNORMtoSNORM_FLT2(Tex);
        }

        // Do transformations here
        [unroll]
        for (int i = 0; i < 3; i++)
        {
            Tex = (Transforms[i] == 0) ? mul(Tex, RotationMatrix) : Tex;
            Tex = (Transforms[i] == 1) ? mul(float3(Tex, 1.0), TranslationMatrix).xy : Tex;
            Tex = (Transforms[i] == 2) ? mul(Tex, ScalingMatrix) : Tex;
        }

        // Scale TexCoord from [-1,1) to [0,1)
        if (ProcessTex)
        {
            Tex = CMath_SNORMtoUNORM_FLT2(Tex);
        }
    }

    int2 CMath_GetScreenSizeFromTex(float2 Tex)
    {
        return max(round(1.0 / fwidth(Tex)), 1.0);
    }

    float2 CMath_GetPixelSizeFromTex(float2 Tex)
    {
        return 1.0 / CMath_GetScreenSizeFromTex(Tex);
    }

    struct CMath_TexGrid
    {
        float2 Tex;
        float2 Frac;
        float2 RowAndColumn;
        float Index;
    };

    CMath_TexGrid CMath_GetTexGrid(float2 Tex, int GridSize)
    {
        CMath_TexGrid Output;
        Output.Tex = Tex * GridSize;
        Output.Frac = frac(Output.Tex);
        Output.RowAndColumn = floor(Output.Tex);
        Output.Index = (Output.RowAndColumn.y * GridSize) + Output.RowAndColumn.x;
        return Output;
    }

    /*
        Functions from Graphics Gems from CryEngine 3
        https://www.advances.realtimerendering.com/s2013/Sousa_Graphics_Gems_CryENGINE3.pptx
    */

    float2 CMath_EncodeVelocity(float2 Velocity)
    {
        return CMath_SNORMtoUNORM_FLT2(sign(Velocity) * sqrt(abs(Velocity)));
    }

    float2 CMath_DecodeVelocity(float2 Velocity)
    {
        Velocity = CMath_UNORMtoSNORM_FLT2(Velocity);
        return (Velocity * Velocity) * sign(Velocity);
    }

    /*
        https://www.shadertoy.com/view/4djSRW

        Copyright (c) 2014 David Hoskins

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.

    */

    float CMath_GetHash_FLT1(float2 P, float Bias)
    {
        float3 P3 = frac(P.xyx * 0.1031);
        P3 += dot(P3, P3.yzx + 33.33);
        return frac(((P3.x + P3.y) * P3.z) + Bias);
    }

    float2 CMath_GetHash_FLT2(float2 P, float2 Bias)
    {
        float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
        P3 += dot(P3, P3.yzx + 33.33);
        return frac(((P3.xx + P3.yz) * P3.zy) + Bias);
    }

    float3 CMath_GetHash_FLT3(float2 P, float3 Bias)
    {
        float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
        P3 += dot(P3, P3.yxz + 33.33);
        return frac(((P3.xxy + P3.yzz) * P3.zyx) + Bias);
    }

    /*
        http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
        https://pbr-book.org/4ed/Sampling_Algorithms/Sampling_Multidimensional_Functions
    */

    float CMath_GetPhi(int D)
    {
        float X = 2.0;

        [unroll]
        for (int i = 0; i < 10; i++)
        {
            X = pow(1.0 + X, 1.0 / (D + 1.0));
        }

        return X;
    }

    float CMath_GetGoldenRatioNoise(float2 Position)
    {
        float P2 = CMath_GetPhi(2);
        return frac(dot(Position, 1.0 / float2(P2, P2 * P2)));
    }

    float2 CMath_MapUVtoConcentricDisk(
        float2 UV // UV [-1, 1)
    )
    {
        float Pi = CMath_GetPi();

        // Handle the special case for the origin
        if (UV.x == 0.0 && UV.y == 0.0)
        {
            return float2(0.0, 0.0);
        }

        // Check if the coordinates are in the first or second half of the square
        float R;
        float Theta;
        if ((UV.x * UV.x) > (UV.y * UV.y))
        {
            R = UV.x;
            Theta = (Pi / 4.0) * (UV.y / UV.x);
        }
        else
        {
            R = UV.y;
            Theta = (Pi / 2.0) - (Pi / 4.0) * (UV.x / UV.y);
        }

        // Convert from polar to Cartesian coordinates
        return R * float2(cos(Theta), sin(Theta));
    }

    /*
        Interleaved Gradient Noise Dithering

        http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx
    */

    float CMath_GetInterleavedGradientNoise(float2 Position)
    {
        return frac(52.9829189 * frac(dot(Position, float2(0.06711056, 0.00583715))));
    }

    /*
        CMath_GetGradientNoise_FLT1(): https://iquilezles.org/articles/gradientnoise/
        CMath_GetQuintic(): https://iquilezles.org/articles/texture/

        The MIT License (MIT)

        Copyright (c) 2017 Inigo Quilez

        Permission is hereby granted, free of charge, to any person obtaining a copy of this
        software and associated documentation files (the "Software"), to deal in the Software
        without restriction, including without limitation the rights to use, copy, modify,
        merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
        permit persons to whom the Software is furnished to do so, subject to the following
        conditions:

        The above copyright notice and this permission notice shall be included in all copies
        or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
        INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
        PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
        HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
        CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
        OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    */

    float2 CMath_GetQuintic(float2 X)
    {
        return X * X * X * (X * (X * 6.0 - 15.0) + 10.0);
    }

    float CMath_GetValueNoise(float2 Tex, float Bias, bool UseQuintic)
    {
        float2 I = floor(Tex);
        float2 F = frac(Tex);
        float A = CMath_GetHash_FLT1(I + float2(0.0, 0.0), Bias);
        float B = CMath_GetHash_FLT1(I + float2(1.0, 0.0), Bias);
        float C = CMath_GetHash_FLT1(I + float2(0.0, 1.0), Bias);
        float D = CMath_GetHash_FLT1(I + float2(1.0, 1.0), Bias);
        float2 UV = UseQuintic ? CMath_GetQuintic(F) : F;
        return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
    }

    float CMath_GetGradient_FLT1(float2 I, float2 F, float2 O, float Bias)
    {
        // Get constants
        const float TwoPi = CMath_GetPi() * 2.0;

        // Calculate random hash rotation
        float Hash = CMath_GetHash_FLT1(I + O, Bias) * TwoPi;
        float2 HashSinCos = float2(sin(Hash), cos(Hash));

        // Calculate final dot-product
        return dot(HashSinCos, F - O);
    }

    float2 CMath_GetGradient_FLT2(float2 I, float2 F, float2 O, float Bias)
    {
        // Get constants
        const float TwoPi = CMath_GetPi() * 2.0;

        // Calculate random hash rotation
        float2 Hash = CMath_GetHash_FLT2(I + O, Bias) * TwoPi;
        float2 HashSinCos1 = float2(sin(Hash.x), cos(Hash.x));
        float2 HashSinCos2 = float2(sin(Hash.y), cos(Hash.y));
        float2 Gradient = F - O;

        // Calculate final dot-product
        return float2(dot(HashSinCos1, Gradient), dot(HashSinCos2, Gradient));
    }

    float3 CMath_GetGradient_FLT3(float2 I, float2 F, float2 O, float Bias)
    {
        // Get constants
        const float TwoPi = CMath_GetPi() * 2.0;

        // Calculate random hash rotation
        float3 Hash = CMath_GetHash_FLT3(I + O, Bias) * TwoPi;
        float2 HashSinCos1 = float2(sin(Hash.x), cos(Hash.x));
        float2 HashSinCos2 = float2(sin(Hash.y), cos(Hash.y));
        float2 HashSinCos3 = float2(sin(Hash.z), cos(Hash.z));
        float2 Gradient = F - O;

        // Calculate final dot-product
        return float3(dot(HashSinCos1, Gradient), dot(HashSinCos2, Gradient), dot(HashSinCos3, Gradient));
    }

    float CMath_GetGradientNoise_FLT1(float2 Tex, float Bias, bool Normalize)
    {
        float2 I = floor(Tex);
        float2 F = frac(Tex);
        float A = CMath_GetGradient_FLT1(I, F, float2(0.0, 0.0), Bias);
        float B = CMath_GetGradient_FLT1(I, F, float2(1.0, 0.0), Bias);
        float C = CMath_GetGradient_FLT1(I, F, float2(0.0, 1.0), Bias);
        float D = CMath_GetGradient_FLT1(I, F, float2(1.0, 1.0), Bias);
        float2 UV = CMath_GetQuintic(F);
        float Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
        Noise = (Normalize) ? saturate(CMath_SNORMtoUNORM_FLT1(Noise)) : Noise;
        return Noise;
    }

    float2 CMath_GetGradientNoise_FLT2(float2 Input, float Bias, bool Normalize)
    {
        float2 I = floor(Input);
        float2 F = frac(Input);
        float2 A = CMath_GetGradient_FLT2(I, F, float2(0.0, 0.0), Bias);
        float2 B = CMath_GetGradient_FLT2(I, F, float2(1.0, 0.0), Bias);
        float2 C = CMath_GetGradient_FLT2(I, F, float2(0.0, 1.0), Bias);
        float2 D = CMath_GetGradient_FLT2(I, F, float2(1.0, 1.0), Bias);
        float2 UV = CMath_GetQuintic(F);
        float2 Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
        Noise = (Normalize) ? saturate(CMath_SNORMtoUNORM_FLT2(Noise)) : Noise;
        return Noise;
    }

    float3 CMath_GetGradientNoise_FLT3(float2 Input, float Bias, bool Normalize)
    {
        float2 I = floor(Input);
        float2 F = frac(Input);
        float3 A = CMath_GetGradient_FLT3(I, F, float2(0.0, 0.0), Bias);
        float3 B = CMath_GetGradient_FLT3(I, F, float2(1.0, 0.0), Bias);
        float3 C = CMath_GetGradient_FLT3(I, F, float2(0.0, 1.0), Bias);
        float3 D = CMath_GetGradient_FLT3(I, F, float2(1.0, 1.0), Bias);
        float2 UV = CMath_GetQuintic(F);
        float3 Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
        Noise = (Normalize) ? saturate(CMath_SNORMtoUNORM_FLT3(Noise)) : Noise;
        return Noise;
    }

    float CMath_GetAntiAliasShape(float Distance, float Radius)
    {
        float AA = fwidth(Distance);
        return smoothstep(Radius - AA, Radius, Distance);
    }

#endif