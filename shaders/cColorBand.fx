
#include "shared/cShade.fxh"
#include "shared/cProcedural.fxh"

/*
    [Shader Options]
*/

uniform int3 _Range <
    ui_label = "Color Band Range";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 32.0;
> = 8;

uniform int _DitherMethod <
    ui_label = "Dither Method";
    ui_type = "combo";
    ui_items = "None\0Hash\0Interleaved Gradient Noise\0";
> = 0;

/*
    [Pixel Shaders]
*/

float4 PS_Color(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 ColorMap = tex2D(CShade_SampleGammaTex, Input.Tex0);

    switch (_DitherMethod)
    {
        case 0:
            ColorMap.rgb = ColorMap.rgb;
            break;
        case 1:
            ColorMap.rgb += (CProcedural_GetHash1(Input.HPos.xy, 0.0) / _Range);
            break;
        case 2:
            ColorMap.rgb += (CProcedural_GetInterleavedGradientNoise(Input.HPos.xy) / _Range);
            break;
        default:
            ColorMap.rgb = ColorMap.rgb;
            break;
    }

    ColorMap.rgb = floor(ColorMap.rgb * _Range) / (_Range);

    return ColorMap;
}

technique CShade_ColorBand
{
    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Color;
    }
}
