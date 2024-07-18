
#include "cMath.fxh"

#if !defined(INCLUDE_CONVOLUTION)
    #define INCLUDE_CONVOLUTION

    /*
        Linear Gaussian blur
        ---
        https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/
    */

    float CConvolution_GetGaussianWeight(float SampleIndex, float Sigma)
    {
        float Output = rsqrt(2.0 * CMath_GetPi() * (Sigma * Sigma));
        return Output * exp(-(SampleIndex * SampleIndex) / (2.0 * Sigma * Sigma));
    }

    float CConvolution_GetGaussianOffset(float SampleIndex, float Sigma, out float LinearWeight)
    {
        float Offset1 = SampleIndex;
        float Offset2 = SampleIndex + 1.0;
        float Weight1 = CConvolution_GetGaussianWeight(Offset1, Sigma);
        float Weight2 = CConvolution_GetGaussianWeight(Offset2, Sigma);
        LinearWeight = Weight1 + Weight2;
        return ((Offset1 * Weight1) + (Offset2 * Weight2)) / LinearWeight;
    }

    float4 CConvolution_GetPixelBlur(VS2PS_Quad Input, sampler2D SampleSource, bool Horizontal)
    {
        // Initialize variables
        const int KernelSize = 10;
        const float4 HShift = float4(-1.0, 0.0, 1.0, 0.0);
        const float4 VShift = float4(0.0, -1.0, 0.0, 1.0);

        float4 OutputColor = 0.0;
        float4 PSize = fwidth(Input.Tex0).xyxy;

        const float Offsets[KernelSize] =
        {
            0.0, 1.490652, 3.4781995, 5.465774, 7.45339,
            9.441065, 11.42881, 13.416645, 15.404578, 17.392626,
        };

        const float Weights[KernelSize] =
        {
            0.06299088, 0.122137636, 0.10790718, 0.08633988, 0.062565096,
            0.04105926, 0.024403222, 0.013135255, 0.006402994, 0.002826693
        };

        // Sample and weight center first to get even number sides
        float TotalWeight = Weights[0];
        OutputColor = tex2D(SampleSource, Input.Tex0 + (Offsets[0] * PSize.xy)) * Weights[0];

        // Sample neighboring pixels
        for(int i = 1; i < KernelSize; i++)
        {
            const float4 Offset = (Horizontal) ? Offsets[i] * HShift: Offsets[i] * VShift;
            float4 Tex = Input.Tex0.xyxy + (Offset * PSize);
            OutputColor += tex2D(SampleSource, Tex.xy) * Weights[i];
            OutputColor += tex2D(SampleSource, Tex.zw) * Weights[i];
            TotalWeight += (Weights[i] * 2.0);
        }

        // Normalize intensity to prevent altered output
        return OutputColor / TotalWeight;
    }

    /*
        Wojciech Sterna's shadow sampling code as a screen-space convolution (http://maxest.gct-game.net/content/chss.pdf)
        ---
        Vogel disk sampling: http://blog.marmakoide.org/?p=1
        Rotated noise sampling: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare (slide 123)
    */

    float2 CConvolution_SampleVogel(int Index, int SamplesCount)
    {
        const float GoldenAngle = CMath_GetPi() * (3.0 - sqrt(5.0));
        float Radius = sqrt(float(Index) + 0.5) * rsqrt(float(SamplesCount));
        float Theta = float(Index) * GoldenAngle;

        float2 SinCosTheta = 0.0;
        SinCosTheta[0] = sin(Theta);
        SinCosTheta[1] = cos(Theta);
        return Radius * SinCosTheta;
    }

    /*
        [Convolutions - Edge Detection]
    */

#endif
