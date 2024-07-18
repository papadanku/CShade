
/*
    https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DoFMedianFilterCS.hlsl
*/

#if !defined(INCLUDE_MATH)
    #define INCLUDE_MATH

    float4 CMath_Max3(float4 A, float4 B, float4 C)
    {
        return max(max(A, B), C);
    }

    float4 CMath_Min3(float4 A, float4 B, float4 C)
    {
        return min(min(A, B), C);
    }

    float4 CMath_Med3(float4 x, float4 y, float4 z)
    {
        return max(min(x, y), min(max(x, y), z));
    }

    float4 Med9(float4 X0, float4 X1, float4 X2,
                float4 X3, float4 X4, float4 X5,
                float4 X6, float4 X7, float4 X8)
    {
        float4 A = CMath_Max3(CMath_Min3(X0, X1, X2), CMath_Min3(X3, X4, X5), CMath_Min3(X6, X7, X8));
        float4 B = CMath_Min3(CMath_Max3(X0, X1, X2), CMath_Max3(X3, X4, X5), CMath_Max3(X6, X7, X8));
        float4 C = CMath_Med3(CMath_Med3(X0, X1, X2), CMath_Med3(X3, X4, X5), CMath_Med3(X6, X7, X8));
        return CMath_Med3(A, B, C);
    }

    float CMath_GetModulus(float X, float Y)
    {
        return X - Y * floor(X / Y);
    }

    float CMath_GetPi()
    {
        return acos(-1.0);
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

#endif