#include "shared/cGraphics.fxh"
#include "shared/cImageProcessing.fxh"

/*
    [Shader Options]
*/

uniform float _Radius <
    ui_label = "Radius";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 64.0;
> = 32.0;

uniform int _Samples <
    ui_label = "Sample Count";
    ui_type = "slider";
    ui_min = 4;
    ui_max = 64;
> = 8;

/*
    [Pixel Shaders]
*/

float4 PS_NoiseBlur(VS2PS_Quad Input) : SV_TARGET0
{
    float4 OutputColor = 0.0;

    const float Pi = acos(-1.0);
    const float2 PixelSize = 1.0 / int2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float Noise = 2.0 * Pi * GetGradientNoise(Input.HPos.xy);

    float2 Rotation = 0.0;
    sincos(Noise, Rotation.y, Rotation.x);

    float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y,
                                      -Rotation.y, Rotation.x);

    for(int i = 0; i < _Samples; i++)
    {
        float2 SampleOffset = mul(SampleVogel(i, _Samples) * _Radius, RotationMatrix);
        OutputColor += tex2Dlod(CShade_SampleColorTex, float4(Input.Tex0 + (SampleOffset * PixelSize), 0.0, 0.0));
    }

    return OutputColor / _Samples;
}

technique CShade_NoiseBlur
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_NoiseBlur;
    }
}
