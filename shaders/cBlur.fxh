
/* Pixel Shaders */

float4 GetGaussianBlur(float2 Tex, float Sigma, bool IsHorizontal)
{
    float2 Direction = IsHorizontal ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 PixelSize = (1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT)) * Direction;
    float KernelSize = Sigma * 3.0;

    if (Sigma == 0.0)
    {
        return tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(Tex));
    }
    else
    {
        // Sample and weight center first to get even number sides
        float TotalWeight = CMath_GetGaussian1D(0.0, Sigma);
        float4 OutputColor = tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(Tex)) * TotalWeight;

        for (float i = 1.0; i < KernelSize; i += 2.0)
        {
            float LinearWeight = 0.0;
            float LinearOffset = CBlur_GetGaussianOffset(i, Sigma, LinearWeight);
            float4 TexA = CShade_PadFloat2(Tex - LinearOffset * PixelSize);
            float4 TexB = CShade_PadFloat2(Tex + LinearOffset * PixelSize);
            OutputColor += tex2Dlod(CShade_SampleColorTex, TexA) * LinearWeight;
            OutputColor += tex2Dlod(CShade_SampleColorTex, TexB) * LinearWeight;
            TotalWeight += LinearWeight * 2.0;
        }

        // Normalize intensity to prevent altered output
        return OutputColor / TotalWeight;
    }
}
