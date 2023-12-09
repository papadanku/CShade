#include "shared/cGraphics.fxh"

/*
    [Shader Options]
*/

uniform int2 _Pixels <
    ui_label = "Number of Pixels";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 1024.0;
> = 512.0;

/*
    [Pixel Shaders]
*/

float4 PS_Color(VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = floor(Input.Tex0 * _Pixels) / _Pixels;
    float4 OutputColor = tex2D(CShade_SampleColorTex, Tex);

    return OutputColor;
}

technique CShade_Pixelate
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Color;
    }
}
