#include "shared/cGraphics.fxh"
#include "shared/cImageProcessing.fxh"

/*
    [Shader Options]
*/

uniform int3 _Range <
    ui_label = "Color Band Range";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 32.0;
> = 8;

uniform bool _Dither <
    ui_label = "Dither";
    ui_type = "radio";
> = true;

/*
    [Pixel Shaders]
*/

float4 PS_Color(VS2PS_Quad Input) : SV_TARGET0
{
    float3 Dither = GetIGNoise(Input.HPos.xy);
    float4 ColorMap = tex2D(CShade_SampleGammaTex, Input.Tex0);

    if (_Dither)
    {
        ColorMap.rgb += (Dither / _Range);
    }

    ColorMap.rgb = floor(ColorMap.rgb * _Range) / (_Range);

    return ColorMap;
}

technique CShade_ColorBand
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Color;
    }
}
