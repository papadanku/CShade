#define CSHADE_QUANTIZE

#include "shared/cProcedural.fxh"

/*
    [Shader Options]
*/

uniform bool _Pixelate <
    ui_category = "Shader | Pixelation";
    ui_label = "Enable";
    ui_type = "radio";
> = false;

uniform int2 _Resolution <
    ui_category = "Shader | Pixelation";
    ui_label = "Resolution";
    ui_type = "slider";
    ui_min = 16;
    ui_max = 256;
> = int2(128, 128);

uniform int3 _Range <
    ui_category = "Shader | Color Banding";
    ui_label = "Color Band Range";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 32.0;
> = 8;

uniform int _DitherMethod <
    ui_category = "Shader | Color Banding";
    ui_label = "Dither Method";
    ui_type = "combo";
    ui_items = "None\0Hash\0Interleaved Gradient Noise\0";
> = 0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Color(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 ColorMapTex = Input.Tex0;
    float2 HashTex = Input.HPos.xy;
    float2 Grid = floor(Input.Tex0 * _Resolution);

    float4 ColorMap = 0.0;
    float3 Dither = 0.0;

    if (_Pixelate)
    {
        HashTex = Grid;
        ColorMap = tex2D(CShade_SampleGammaTex, Grid / _Resolution);
    }
    else
    {
        ColorMap = tex2D(CShade_SampleGammaTex, Input.Tex0);
    }

    switch (_DitherMethod)
    {
        case 0:
            Dither = 0.0;
            break;
        case 1:
            Dither = CProcedural_GetHash1(HashTex, 0.0) / _Range;
            break;
        case 2:
            Dither = CProcedural_GetInterleavedGradientNoise(HashTex) / _Range;
            break;
        default:
            Dither = 0.0;
            break;
    }

    // Color quantization
    ColorMap.rgb += (Dither / _Range);
    ColorMap.rgb = floor(ColorMap.rgb * _Range) / _Range;

    return CBlend_OutputChannels(float4(ColorMap.rgb, _CShadeAlphaFactor));
}

technique CShade_Quantize < ui_tooltip = "Artificial quantization effect"; >
{
    pass
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Color;
    }
}
