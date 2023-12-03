#include "shared/cGraphics.fxh"

/*
    [Shader Options]
*/

uniform int3 _Range <
    ui_label = "Color Band Range";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 32.0;
> = 8;

/*
    [Pixel Shaders]
*/

float4 PS_Color(VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleGammaTex, Input.Tex0);
    Color.rgb = floor(Color.rgb * _Range) / (_Range);

    return Color;
}

technique CShade_ColorBand
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Color;
    }
}
