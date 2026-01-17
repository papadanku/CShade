#define CSHADE_QUANTIZE

/*
    This shader applies an artificial quantization effect to the image, reducing the number of distinct colors and creating a posterized or pixel art aesthetic. It includes options for pixelation, which renders the image with larger, blocky pixels, and dithering, which minimizes color banding by introducing controlled noise. Users can customize the pixelation resolution, the number of quantization levels for each color channel, and the dithering algorithm.
*/

#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform bool _Pixelate <
    ui_category = "Main Shader";
    ui_label = "Enable Pixelated Effect";
    ui_type = "radio";
    ui_tooltip = "When enabled, the image will be rendered with a blocky, pixelated appearance.";
> = false;

uniform bool _Dithering <
    ui_category = "Main Shader";
    ui_label = "Enable Dithering Effect";
    ui_type = "radio";
    ui_tooltip = "When enabled, dithering is applied to reduce color banding and create the illusion of more colors.";
> = false;

uniform int _DitherMethod <
    ui_category = "Main Shader";
    ui_items = "Golden Ratio Noise\0Interleaved Gradient Noise\0White Noise\0";
    ui_label = "Dither Pattern Algorithm";
    ui_type = "combo";
    ui_tooltip = "Selects the algorithm used to generate the dither pattern, such as Golden Ratio Noise or White Noise.";
> = 0;

uniform int2 _Resolution <
    ui_category = "Main Shader";
    ui_label = "Pixelation Block Resolution";
    ui_max = 256;
    ui_min = 16;
    ui_type = "slider";
    ui_tooltip = "Sets the number of pixels horizontally and vertically when pixelation is enabled, controlling the block size.";
> = int2(128, 128);

uniform int3 _Range <
    ui_category = "Main Shader";
    ui_label = "Quantization Levels";
    ui_max = 32.0;
    ui_min = 1.0;
    ui_type = "slider";
    ui_tooltip = "Defines the number of distinct color bands available for each color channel, creating a quantized or posterized look.";
> = 8;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
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
                Dither = CMath_GetInterleavedGradientNoise(HashPos) / _Range;
                break;
            case 2:
                Dither = CMath_GetHash_FLT1(HashPos, 0.0) / _Range;
                break;
            default:
                Dither = 0.0;
                break;
        }
    }

    // Color quantization
    ColorMap.rgb += (Dither / _Range);
    ColorMap.rgb = floor(ColorMap.rgb * _Range) / _Range;

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(ColorMap.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(ColorMap.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos, Input.Tex0);
}

technique CShade_Quantize
<
    ui_label = "CShade | Quantize";
    ui_tooltip = "Artificial quantization effect.";
>
{
    pass Quantize
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
