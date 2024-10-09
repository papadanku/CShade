
/*
    https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DoFMedianFilterCS.hlsl
*/

#if !defined(INCLUDE_CMATH)
    #define INCLUDE_CMATH

    float4 CMath_Float4_Max3(float4 A, float4 B, float4 C)
    {
        return max(max(A, B), C);
    }

    float4 CMath_Float4_Min3(float4 A, float4 B, float4 C)
    {
        return min(min(A, B), C);
    }

    float4 CMath_Float4_Med3(float4 x, float4 y, float4 z)
    {
        return max(min(x, y), min(max(x, y), z));
    }

    float CMath_Float1_Med3(float x, float y, float z)
    {
        return max(min(x, y), min(max(x, y), z));
    }

    float4 CMath_Float4_Med9(
        float4 X0, float4 X1, float4 X2,
        float4 X3, float4 X4, float4 X5,
        float4 X6, float4 X7, float4 X8)
    {
        float4 A = CMath_Float4_Max3(CMath_Float4_Min3(X0, X1, X2), CMath_Float4_Min3(X3, X4, X5), CMath_Float4_Min3(X6, X7, X8));
        float4 B = CMath_Float4_Min3(CMath_Float4_Max3(X0, X1, X2), CMath_Float4_Max3(X3, X4, X5), CMath_Float4_Max3(X6, X7, X8));
        float4 C = CMath_Float4_Med3(CMath_Float4_Med3(X0, X1, X2), CMath_Float4_Med3(X3, X4, X5), CMath_Float4_Med3(X6, X7, X8));
        return CMath_Float4_Med3(A, B, C);
    }

    float CMath_Float1_GetModulus(float X, float Y)
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

    float2 CMath_Transform2D(
        float2 Tex, // [-1, 1]
        float Angle,
        float2 Translate,
        float2 Scale
    )
    {
        float2x2 RotationMatrix = CMath_GetRotationMatrix(Angle);

        float3x3 TranslationMatrix = float3x3
        (
            1.0, 0.0, 0.0, // Row 1
            0.0, 1.0, 0.0, // Row 2
            Translate.x, Translate.y, 1.0 // Row 3
        );

        float2x2 ScalingMatrix = float2x2
        (
            Scale.x, 0.0, // Row 1
            0.0, Scale.y // Row 2
        );

        // Scale TexCoord from [0,1] to [-1,1]
        Tex = (Tex * 2.0) - 1.0;

        // Do transformations here
        Tex = mul(Tex, RotationMatrix);
        Tex = mul(float3(Tex, 1.0), TranslationMatrix).xy;
        Tex = mul(Tex, ScalingMatrix);

        // Scale TexCoord from [-1,1] to [0,1]
        Tex = (Tex * 0.5) + 0.5;

        return Tex;
    }


    float CMath_GetHalfMax()
    {
        // Get the Half format distribution of bits
        // Sign Exponent Significand
        // 0    00000    000000000
        const int SignBit = 0;
        const int ExponentBits = 5;
        const int SignificandBits = 10;

        const int Bias = -15;
        const int Exponent = exp2(ExponentBits);
        const int Significand = exp2(SignificandBits);

        const float MaxExponent = ((float)Exponent - (float)exp2(1)) + (float)Bias;
        const float MaxSignificand = 1.0 + (((float)Significand - 1.0) / (float)Significand);

        return (float)pow(-1, SignBit) * (float)exp2(MaxExponent) * MaxSignificand;
    }

    // [-HalfMax, HalfMax) -> [-1.0, 1.0)
    float2 CMath_HalfToNorm(float2 Half2)
    {
        return clamp(Half2 / CMath_GetHalfMax(), -1.0, 1.0);
    }

    // [-1.0, 1.0) -> [-HalfMax, HalfMax)
    float2 CMath_NormToHalf(float2 Half2)
    {
        return Half2 * CMath_GetHalfMax();
    }

#endif
