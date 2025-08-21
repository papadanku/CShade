#define CSHADE_QUANTIZE

#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform bool _Pixelate <
    ui_label = "Enable Pixelation";
    ui_type = "radio";
> = false;

uniform bool _Dithering <
    ui_label = "Enable Dithering";
    ui_type = "radio";
> = false;

uniform int _DitherMethod <
    ui_label = "Dither Algorithm";
    ui_type = "combo";
    ui_items = "Golden Ratio\0Hash\0Interleaved Gradient Noise\0";
> = 0;

uniform int2 _Resolution <
    ui_label = "Pixel Count";
    ui_type = "slider";
    ui_min = 16;
    ui_max = 256;
> = int2(128, 128);

uniform int3 _Range <
    ui_label = "Color Banding Range";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 32.0;
> = 8;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Color(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 ColorMapTex = Input.Tex0;
    float2 HashPos = Input.HPos.xy;
    float2 Grid = floor(Input.Tex0 * _Resolution);

    float4 ColorMap = 0.0;
    float3 Dither = 0.0;

    if (_Pixelate)
    {
        HashPos = Grid;
        ColorMap = tex2D(CShade_SampleGammaTex, Grid / _Resolution);
    }
    else
    {
        ColorMap = tex2D(CShade_SampleGammaTex, Input.Tex0);
    }

    if (_Dithering)
    {
        switch (_DitherMethod)
        {
            case 0:
                Dither = CMath_GetGoldenRatioNoise(HashPos) / _Range;
                break;
            case 1:
                Dither = CMath_GetHash1(HashPos, 0.0) / _Range;
                break;
            case 2:
                Dither = CMath_GetInterleavedGradientNoise(HashPos) / _Range;
                break;
            default:
                Dither = 0.0;
                break;
        }
    }

    // Color quantization
    ColorMap.rgb += (Dither / _Range);
    ColorMap.rgb = floor(ColorMap.rgb * _Range) / _Range;

    return CBlend_OutputChannels(float4(ColorMap.rgb, _CShadeAlphaFactor));
}

technique CShade_Quantize
<
    ui_label = "CShade · Quantize";
    ui_tooltip = "Artificial quantization effect.";
>
{
    pass
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Color;
    }
}
