
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

    float CMath_GetPasticRatio()
    {
        float N = (1.0 / 3.0) * sqrt(23.0 / 3.0);
        float W1 = (1.0 / 2.0) * (1.0 + N);
        float W2 = (1.0 / 2.0) * (1.0 - N);
        return pow(W1, 1.0 / 3.0) + pow(W2, 1.0 / 3.0);
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

    // Get the Half format distribution of bits
    // Sign Exponent Significand
    // x    xxxxx    xxxxxxxxxx
    float CMath_CalculateFP16(int Sign, int Exponent, int Significand)
    {
        const int Bias = -15;
        const int MaxExponent = (Exponent - exp2(1)) + Bias;
        const int MaxSignificand = 1 + ((Significand - 1) / Significand);

        return (float)pow(-1, Sign) * (float)exp2(MaxExponent) * (float)MaxSignificand;
    }

    float CMath_GetFP16Min()
    {
        /*
            Sign Exponent Significand
            ---- -------- -----------
            0    00001    000000000
        */
        return CMath_CalculateFP16(0, exp2(1) + 1, exp2(0));
    }

    float CMath_GetFP16Max()
    {
        /*
            Sign Exponent Significand
            ---- -------- -----------
            0    11110    1111111111
        */
        return CMath_CalculateFP16(0, exp2(5), exp2(10));
    }

    // [-HalfMax, HalfMax) -> [-1.0, 1.0)
    float2 CMath_Float2_FP16ToNorm(float2 Half2)
    {
        return Half2 / CMath_GetFP16Max();
    }

    float4 CMath_Float4_FP16ToNorm(float4 Half4)
    {
        return Half4 / CMath_GetFP16Max();
    }

    // [-1.0, 1.0) -> [-HalfMax, HalfMax)
    float2 CMath_Float2_NormToFP16(float2 Half2)
    {
        return Half2 * CMath_GetFP16Max();
    }

    float4 CMath_Float4_NormToFP16(float4 Half4)
    {
        return Half4 * CMath_GetFP16Max();
    }

    /*
        Functions from Graphics Gems from CryEngine 3
        https://www.advances.realtimerendering.com/s2013/Sousa_Graphics_Gems_CryENGINE3.pptx
    */

    float2 CMath_EncodeVelocity(float2 Velocity)
    {
        return (sign(Velocity) * sqrt(abs(Velocity)) * 0.5) + 0.5;
    }

    float2 CMath_DecodeVelocity(float2 Velocity)
    {
        Velocity = (Velocity * 2.0) - 1.0;
        return (Velocity * Velocity) * sign(Velocity);
    }

#endif
