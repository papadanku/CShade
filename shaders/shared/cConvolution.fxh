
#if !defined(INCLUDE_CONVOLUTION)
    #define INCLUDE_CONVOLUTION

    /*
        Linear Gaussian blur
        ---
        https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/
    */

    float GetGaussianWeight(float SampleIndex, float Sigma)
    {
        const float Pi = acos(-1.0);
        float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
        return Output * exp(-(SampleIndex * SampleIndex) / (2.0 * Sigma * Sigma));
    }

    float GetGaussianOffset(float SampleIndex, float Sigma, out float LinearWeight)
    {
        float Offset1 = SampleIndex;
        float Offset2 = SampleIndex + 1.0;
        float Weight1 = GetGaussianWeight(Offset1, Sigma);
        float Weight2 = GetGaussianWeight(Offset2, Sigma);
        LinearWeight = Weight1 + Weight2;
        return ((Offset1 * Weight1) + (Offset2 * Weight2)) / LinearWeight;
    }

    float4 GetPixelBlur(VS2PS_Quad Input, sampler2D SampleSource, bool Horizontal)
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

    float2 SampleVogel(int Index, int SamplesCount)
    {
        const float Pi = acos(-1.0);
        const float GoldenAngle = Pi * (3.0 - sqrt(5.0));
        float Radius = sqrt(float(Index) + 0.5) * rsqrt(float(SamplesCount));
        float Theta = float(Index) * GoldenAngle;

        float2 SinCosTheta = 0.0;
        SinCosTheta[0] = sin(Theta);
        SinCosTheta[1] = cos(Theta);
        return Radius * SinCosTheta;
    }

    float4 Filter3x3(sampler2D SampleSource, float2 Tex, bool DownSample)
    {
        const float3 Weights = float3(1.0, 2.0, 4.0) / 16.0;
        float2 PixelSize = fwidth(Tex);
        PixelSize = (DownSample) ? PixelSize * 0.5 : PixelSize;

        float4 STex[3] =
        {
            Tex.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * abs(PixelSize.xyyy)),
            Tex.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * abs(PixelSize.xyyy)),
            Tex.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * abs(PixelSize.xyyy))
        };

        float4 OutputColor = 0.0;
        OutputColor += (tex2D(SampleSource, STex[0].xy) * Weights[0]);
        OutputColor += (tex2D(SampleSource, STex[1].xy) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[2].xy) * Weights[0]);
        OutputColor += (tex2D(SampleSource, STex[0].xz) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[1].xz) * Weights[2]);
        OutputColor += (tex2D(SampleSource, STex[2].xz) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[0].xw) * Weights[0]);
        OutputColor += (tex2D(SampleSource, STex[1].xw) * Weights[1]);
        OutputColor += (tex2D(SampleSource, STex[2].xw) * Weights[0]);
        return OutputColor;
    }

    /*
        [Convolutions - Edge Detection]
    */

    /*
        Linear filtered Sobel filter
    */

    struct VS2PS_Sobel
    {
        float4 HPos : SV_POSITION;
        float4 Tex0 : TEXCOORD0;
    };

    VS2PS_Sobel GetVertexSobel(APP2VS Input, float2 PixelSize)
    {
        VS2PS_Quad FSQuad = VS_Quad(Input);

        VS2PS_Sobel Output;
        Output.HPos = FSQuad.HPos;
        Output.Tex0 = FSQuad.Tex0.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * PixelSize.xyxy);
        return Output;
    }

    float2 GetPixelSobel(VS2PS_Sobel Input, sampler2D SampleSource)
    {
        float2 OutputColor0 = 0.0;
        float A = tex2D(SampleSource, Input.Tex0.xw).r * 4.0; // <-0.5, +0.5>
        float B = tex2D(SampleSource, Input.Tex0.zw).r * 4.0; // <+0.5, +0.5>
        float C = tex2D(SampleSource, Input.Tex0.xy).r * 4.0; // <-0.5, -0.5>
        float D = tex2D(SampleSource, Input.Tex0.zy).r * 4.0; // <+0.5, -0.5>
        OutputColor0.x = ((B + D) - (A + C)) / 4.0;
        OutputColor0.y = ((A + B) - (C + D)) / 4.0;
        return OutputColor0;
    }

#endif
