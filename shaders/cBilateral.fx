#include "shared/cGraphics.fxh"
#include "shared/cImageProcessing.fxh"

uniform float _Offset <
    ui_label = "Sample Offset";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.0;

uniform float _Radius <
    ui_label = "Radius";
    ui_type = "drag";
    ui_min = 0.0;
> = 16.0;

uniform int _Samples <
    ui_label = "Sample Count";
    ui_type = "drag";
    ui_min = 0;
> = 16;

CREATE_SAMPLER(SampleTempTex1, TempTex1_RGBA16F, LINEAR, CLAMP)

float4 PS_Bilateral(VS2PS_Quad Input) : SV_TARGET0
{
    // Initialize variables we need to accumulate samples and calculate offsets
    float4 OutputColor = 0.0;

    // Offset and weighting attributes
    float2 PixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);

    // Get bilateral filter
    float3 TotalWeight = 0.0;
    float3 Center = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    for(int i = 0; i < _Samples; i++)
    {
        float2 Offset = SampleVogel(i, _Samples) * _Radius;
        float3 Pixel = tex2D(CShade_SampleColorTex, Input.Tex0 + (Offset * PixelSize)).rgb;
        float3 Weight = abs(1.0 - abs(Pixel - Center));
        OutputColor += (Pixel * Weight);
        TotalWeight += Weight;
    }
    OutputColor.rgb /= TotalWeight;

    return OutputColor;
}

technique CShade_Bilateral
{
    pass GenMipLevels
    {
        VertexShader = VS_Quad;
        PixelShader = PS_GenMipLevels;
        RenderTarget0 = TempTex1_RGBA16F;
    }

    pass Bilateral
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Bilateral;
    }
}
