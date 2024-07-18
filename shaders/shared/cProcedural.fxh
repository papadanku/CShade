
#include "cMath.fxh"

#if !defined(INCLUDE_PROCEDURAL)
    #define INCLUDE_PROCEDURAL

    /*
        https://www.shadertoy.com/view/4djSRW

        Copyright (c) 2014 David Hoskins

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    */

    float CProcedural_GetHash1(float2 P, float Bias)
    {
        float3 P3 = frac(P.xyx * 0.1031);
        P3 += dot(P3, P3.yzx + 33.33);
        return frac(((P3.x + P3.y) * P3.z) + Bias);
    }

    float2 CProcedural_GetHash2(float2 P, float2 Bias)
    {
        float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
        P3 += dot(P3, P3.yzx + 33.33);
        return frac(((P3.xx + P3.yz) * P3.zy) + Bias);
    }

    float3 CProcedural_GetHash3(float2 P, float3 Bias)
    {
        float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
        P3 += dot(P3, P3.yxz + 33.33);
        return frac(((P3.xxy + P3.yzz) * P3.zyx) + Bias);
    }

    /*
        Interleaved Gradient Noise Dithering
        ---
        http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx
    */

    float CProcedural_GetInterleavedGradientNoise(float2 Position)
    {
        return frac(52.9829189 * frac(dot(Position, float2(0.06711056, 0.00583715))));
    }

    /*
        CProcedural_GetGradientNoise1(): https://iquilezles.org/articles/gradientnoise/
        CProcedural_GetQuintic(): https://iquilezles.org/articles/texture/

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

    float2 CProcedural_GetQuintic(float2 X)
    {
        return X * X * X * (X * (X * 6.0 - 15.0) + 10.0);
    }

    float CProcedural_GetValueNoise(float2 Tex, float Bias)
    {
        float2 I = floor(Tex);
        float2 F = frac(Tex);
        float A = CProcedural_GetHash1(I + float2(0.0, 0.0), Bias);
        float B = CProcedural_GetHash1(I + float2(1.0, 0.0), Bias);
        float C = CProcedural_GetHash1(I + float2(0.0, 1.0), Bias);
        float D = CProcedural_GetHash1(I + float2(1.0, 1.0), Bias);
        float2 UV = CProcedural_GetQuintic(F);
        return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
    }

    float CProcedural_GetGradient1(float2 I, float2 F, float2 O, float Bias)
    {
        // Get constants
        const float TwoPi = CMath_GetPi() * 2.0;

        // Calculate random hash rotation
        float Hash = CProcedural_GetHash1(I + O, Bias) * TwoPi;
        float2 HashSinCos = float2(sin(Hash), cos(Hash));

        // Calculate final dot-product
        return dot(HashSinCos, F - O);
    }

    float2 CProcedural_GetGradient2(float2 I, float2 F, float2 O, float Bias)
    {
        // Get constants
        const float TwoPi = CMath_GetPi() * 2.0;

        // Calculate random hash rotation
        float2 Hash = CProcedural_GetHash2(I + O, Bias) * TwoPi;
        float4 HashSinCos = float4(sin(Hash), cos(Hash));
        float2 Gradient = F - O;

        // Calculate final dot-product
        return float2(dot(HashSinCos.xz, Gradient), dot(HashSinCos.yw, Gradient));
    }

    float CProcedural_GetGradientNoise1(float2 Tex, float Bias)
    {
        float2 I = floor(Tex);
        float2 F = frac(Tex);
        float A = CProcedural_GetGradient1(I, F, float2(0.0, 0.0), Bias);
        float B = CProcedural_GetGradient1(I, F, float2(1.0, 0.0), Bias);
        float C = CProcedural_GetGradient1(I, F, float2(0.0, 1.0), Bias);
        float D = CProcedural_GetGradient1(I, F, float2(1.0, 1.0), Bias);
        float2 UV = CProcedural_GetQuintic(F);
        float Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
        return saturate((Noise * 0.5) + 0.5);
    }

    float2 GetGradientNoise2(float2 Input, float Bias, bool NormalizeOutput)
    {
        float2 I = floor(Input);
        float2 F = frac(Input);
        float2 A = CProcedural_GetGradient2(I, F, float2(0.0, 0.0), Bias);
        float2 B = CProcedural_GetGradient2(I, F, float2(1.0, 0.0), Bias);
        float2 C = CProcedural_GetGradient2(I, F, float2(0.0, 1.0), Bias);
        float2 D = CProcedural_GetGradient2(I, F, float2(1.0, 1.0), Bias);
        float2 UV = CProcedural_GetQuintic(F);
        float2 Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
        Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
        return Noise;
    }

    float CProcedural_GetAntiAliasShape(float Distance, float Radius)
    {
        float AA = fwidth(Distance);
        return smoothstep(Radius - AA, Radius, Distance);
    }

#endif
