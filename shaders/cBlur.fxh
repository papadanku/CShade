
/*
    [Shader Options]
*/

uniform float _Sigma <
    ui_label = "Sigma";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 16.0;
> = 1.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#include "shared/cBlur.fxh"

/*
    [Pixel Shaders]
*/

float4 GetGaussianBlur(float2 Tex, bool IsHorizontal)
{
    float2 Direction = IsHorizontal ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 PixelSize = (1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT)) * Direction;
    float KernelSize = _Sigma * 3.0;

    if(_Sigma == 0.0)
    {
        return CShadeHDR_Tex2Dlod_InvTonemap(CShade_SampleColorTex, float4(Tex, 0.0, 0.0));
    }
    else
    {
        // Sample and weight center first to get even number sides
        float TotalWeight = CBlur_GetGaussianWeight(0.0, _Sigma);
        float4 OutputColor = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Tex) * TotalWeight;

        for(float i = 1.0; i < KernelSize; i += 2.0)
        {
            float LinearWeight = 0.0;
            float LinearOffset = CBlur_GetGaussianOffset(i, _Sigma, LinearWeight);
            float4 TexA = float4(Tex - LinearOffset * PixelSize, 0.0, 0.0);
            float4 TexB = float4(Tex + LinearOffset * PixelSize, 0.0, 0.0);
            OutputColor += CShadeHDR_Tex2Dlod_InvTonemap(CShade_SampleColorTex, TexA) * LinearWeight;
            OutputColor += CShadeHDR_Tex2Dlod_InvTonemap(CShade_SampleColorTex, TexB) * LinearWeight;
            TotalWeight += LinearWeight * 2.0;
        }

        // Normalize intensity to prevent altered output
        return OutputColor / TotalWeight;
    }
}

float4 PS_HGaussianBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CBlend_OutputChannels(float4(GetGaussianBlur(Input.Tex0, true).rgb, _CShadeAlphaFactor));
}

float4 PS_VGaussianBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CBlend_OutputChannels(float4(GetGaussianBlur(Input.Tex0, false).rgb, _CShadeAlphaFactor));
}
