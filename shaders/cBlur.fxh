
/*
    [Shader Options]
*/

#include "shared/cBlur.fxh"

uniform float _Sigma <
    ui_category = "Main Shader";
    ui_label = "Blur Strength";
    ui_max = 16.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the spread of the Gaussian blur. Higher values result in a wider and more intense blur.";
> = 1.0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/*
    [Pixel Shaders]
*/

float4 GetGaussianBlur(float2 Tex, bool IsHorizontal)
{
    float2 Direction = IsHorizontal ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 PixelSize = (1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT)) * Direction;
    float KernelSize = _Sigma * 3.0;

    if (_Sigma == 0.0)
    {
        return tex2Dlod(CShade_SampleColorTex, float4(Tex, 0.0, 0.0));
    }
    else
    {
        // Sample and weight center first to get even number sides
        float TotalWeight = CBlur_GetGaussianWeight1D(0.0, _Sigma);
        float4 OutputColor = tex2Dlod(CShade_SampleColorTex, float4(Tex, 0.0, 0.0)) * TotalWeight;

        for (float i = 1.0; i < KernelSize; i += 2.0)
        {
            float LinearWeight = 0.0;
            float LinearOffset = CBlur_GetGaussianOffset(i, _Sigma, LinearWeight);
            float4 TexA = float4(Tex - LinearOffset * PixelSize, 0.0, 0.0);
            float4 TexB = float4(Tex + LinearOffset * PixelSize, 0.0, 0.0);
            OutputColor += tex2Dlod(CShade_SampleColorTex, TexA) * LinearWeight;
            OutputColor += tex2Dlod(CShade_SampleColorTex, TexB) * LinearWeight;
            TotalWeight += LinearWeight * 2.0;
        }

        // Normalize intensity to prevent altered output
        return OutputColor / TotalWeight;
    }
}
