
/*
    https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DoFMedianFilterCS.hlsl
*/

#if !defined(INCLUDE_MATH)
    #define INCLUDE_MATH

    float4 Max3(float4 A, float4 B, float4 C)
    {
        return max(max(A, B), C);
    }

    float4 Min3(float4 A, float4 B, float4 C)
    {
        return min(min(A, B), C);
    }

    float Med3(float x, float y, float z)
    {
        return max(min(x, y), min(max(x, y), z));
    }

    float4 Med9(float4 X0, float4 X1, float4 X2,
                float4 X3, float4 X4, float4 X5,
                float4 X6, float4 X7, float4 X8)
    {
        float4 A = Max3(Min3(X0, X1, X2), Min3(X3, X4, X5), Min3(X6, X7, X8));
        float4 B = Min3(Max3(X0, X1, X2), Max3(X3, X4, X5), Max3(X6, X7, X8));
        float4 C = Med3(Med3(X0, X1, X2), Med3(X3, X4, X5), Med3(X6, X7, X8));
        return Med3(A, B, C);
    }

#endif