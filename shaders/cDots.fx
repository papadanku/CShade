#define CSHADE_DOTS

#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

#ifndef SHADER_TOGGLE_MONO
    #define SHADER_TOGGLE_MONO 0
#endif

#if !SHADER_TOGGLE_MONO
    uniform bool _InvertProcessing <
        ui_category = "Main Shader";
        ui_label = "Invert Effect";
        ui_type = "radio";
        ui_tooltip = "Reverses the effect of the dot pattern, swapping foreground and background colors.";
    > = false;
#endif

#if SHADER_TOGGLE_MONO
    uniform int _Select <
        ui_category = "Main Shader";
        ui_items = "HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
        ui_label = "Monochrome Feature Selection";
        ui_type = "combo";
        ui_tooltip = "Determines which color feature (Hue, Saturation, or Value) is used to generate the dot pattern in monochrome mode.";
    > = 2;
#endif

uniform int _CircleAmount <
    ui_category = "Main Shader";
    ui_label = "Dot Density";
    ui_max = 256;
    ui_min = 1;
    ui_type = "slider";
    ui_tooltip = "Sets the number of circles horizontally and vertically across the screen, influencing the density of the dot pattern.";
> = 128;

uniform float _InputMultiplier <
    ui_category = "Main Shader / Input Color";
    ui_label = "Input Color Influence";
    ui_max = 8.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the intensity of the input color data before it's used to determine the size of the circles.";
> = 4.0;

uniform float _InputBias <
    ui_category = "Main Shader / Input Color";
    ui_label = "Input Color Bias";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adds a constant value to the input color data, shifting the overall brightness that influences circle size.";
> = 0.0;

#if SHADER_TOGGLE_MONO
    uniform float2 _Offset <
        ui_category = "Main Shader / Geometry";
        ui_label = " ";
        ui_max = 100.0;
        ui_min = -100.0;
        ui_text = "Offset (Horizontal, Vertical)";
        ui_type = "slider";
        ui_tooltip = "Adjusts the horizontal and vertical position of the dot pattern on the screen.";
    > = 0.0;

    uniform int4 _Crop <
        ui_category = "Main Shader / Geometry";
        ui_label = " ";
        ui_max = 10;
        ui_min = 0;
        ui_text = "Crop (Left, Right, Top, Bottom)";
        ui_type = "slider";
        ui_tooltip = "Defines the cropping boundaries (left, right, top, bottom) for the dot pattern, effectively trimming the effect from the edges.";
    > = 0;
#else
    uniform float2 _RedChannelOffset <
        ui_category = "Main Shader / Geometry";
        ui_label = "Red Channel Offset";
        ui_max = 10.0;
        ui_min = -10.0;
        ui_step = 0.1;
        ui_text = "Offset (Horizontal, Vertical)";
        ui_type = "slider";
        ui_tooltip = "Adjusts the horizontal and vertical offset for the red channel's dot pattern.";
    > = 0.0;

    uniform float2 _GreenChannelOffset <
        ui_category = "Main Shader / Geometry";
        ui_label = "Green Channel Offset";
        ui_max = 10.0;
        ui_min = -10.0;
        ui_step = 0.1;
        ui_type = "slider";
        ui_tooltip = "Adjusts the horizontal and vertical offset for the green channel's dot pattern.";
    > = 0.0;

    uniform float2 _BlueChannelOffset <
        ui_category = "Main Shader / Geometry";
        ui_label = "Blue";
        ui_max = 10.0;
        ui_min = -10.0;
        ui_step = 0.1;
        ui_type = "slider";
        ui_tooltip = "Adjusts the horizontal and vertical offset for the blue channel's dot pattern.";
    > = 0.0;

    uniform int4 _RedChannelCrop <
        ui_category = "Main Shader / Geometry";
        ui_label = "Red Channel Crop";
        ui_max = 10;
        ui_min = 0;
        ui_text = "Crop (Left, Right, Top, Bottom)";
        ui_type = "slider";
        ui_tooltip = "Defines the cropping boundaries (left, right, top, bottom) for the red channel's dot pattern.";
    > = 0;

    uniform int4 _GreenChannelCrop <
        ui_category = "Main Shader / Geometry";
        ui_label = "Green Channel Crop";
        ui_max = 10;
        ui_min = 0;
        ui_type = "slider";
        ui_tooltip = "Defines the cropping boundaries (left, right, top, bottom) for the green channel's dot pattern.";
    > = 0;

    uniform int4 _BlueChannelCrop <
        ui_category = "Main Shader / Geometry";
        ui_label = "Blue Channel Crop";
        ui_max = 10;
        ui_min = 0;
        ui_type = "slider";
        ui_tooltip = "Defines the cropping boundaries (left, right, top, bottom) for the blue channel's dot pattern.";
    > = 0;
#endif

uniform float3 _FrontColor <
    ui_category = "Main Shader / Composition";
    ui_label = "Dot Color";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Sets the color of the dots (foreground) in the pattern.";
> = float3(0.0, 0.0, 0.0);

uniform float3 _BackColor <
    ui_category = "Main Shader / Composition";
    ui_label = "Background Color";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Sets the background color behind the dots in the pattern.";
> = float3(1.0, 1.0, 1.0);

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nSHADER_TOGGLE_MONO - Switches to the shader's monochrome version.\n\n\tOptions: 0 (disabled), 1 (enabled)\n\n";
    ui_type = "radio";
> = 0;

/*
    [Textures and Samplers]
*/

CSHADE_CREATE_TEXTURE_POOLED(TempTex0_RGBA8_8, CSHADE_BUFFER_SIZE_0, RGBA8, 8)
CSHADE_CREATE_SRGB_SAMPLER(SampleTempTex0, TempTex0_RGBA8_8, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)

sampler2D CShade_SampleColorTexMirror
{
    Texture = CShade_ColorTex;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = CSHADE_READ_SRGB;
};

/*
    [Functions]
*/

struct Tile
{
    float2 Value;
    float2 Index;
    float2 Frac;
};

Tile GetTiles(float2 Tex, float2 Translation)
{
    Tile Output;

    float2 Tiles = Tex + (Translation * fwidth(Tex));

    // Get tiles
    Output.Value = Tiles * _CircleAmount;

    // Shift the tiles so they are ~0.5 units apart from each-other
    Output.Value.x = (CMath_GetModulus_FLT1(trunc(Output.Value.y), 2.0) == 1.0) ? Output.Value.x + 0.25: Output.Value.x - 0.25;

    // Get tile index
    Output.Index = floor(Output.Value);

    // Get fractional variant of file
    Output.Frac = frac(Output.Value);

    return Output;
}

float2 GetBlockTex(float2 TileIndex)
{
    return TileIndex / _CircleAmount;
}

float GetTileCircleLength(Tile Input)
{
    // Create the UV for the circles
    float2 CircleTiles = CMath_UNORMtoSNORM_FLT2(Input.Frac);
    // Shrink the UV so [-1, 1] fills a square
    #if BUFFER_WIDTH > BUFFER_HEIGHT
        CircleTiles.x *= CSHADE_ASPECT_RATIO;
    #else
        CircleTiles.y *= CSHADE_ASPECT_RATIO;
    #endif

    return length(CircleTiles);
}

#if !SHADER_TOGGLE_MONO
    void CropChannel(inout float Channel, in int BackComponent, in Tile ChannelTiles, in float4 CropArgs)
    {
        // Crop the image
        float SrcColor = _BackColor[BackComponent];
        Channel = lerp(SrcColor, Channel, ChannelTiles.Value.x > CropArgs.x);
        Channel = lerp(SrcColor, Channel, ChannelTiles.Value.x < (_CircleAmount - CropArgs.y));
        Channel = lerp(SrcColor, Channel, ChannelTiles.Value.y > CropArgs.z * 2.0);
        Channel = lerp(SrcColor, Channel, ChannelTiles.Value.y < (_CircleAmount - CropArgs.w * 2.0));
    }
#endif

/*
    [Pixel Shaders]
*/

void PS_Blit(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0);

    #if SHADER_TOGGLE_MONO
        switch(_Select)
        {
            case 0:
                Output.a = CColor_RGBtoHSV(Output.rgb).r;
                break;
            case 1:
                Output.a = CColor_RGBtoHSV(Output.rgb).g;
                break;
            case 2:
                Output.a = CColor_RGBtoHSV(Output.rgb).b;
                break;
            case 3:
                Output.a = CColor_RGBtoHSL(Output.rgb).r;
                break;
            case 4:
                Output.a = CColor_RGBtoHSL(Output.rgb).g;
                break;
            case 5:
                Output.a = CColor_RGBtoHSL(Output.rgb).b;
                break;
            case 6:
                Output.a = CColor_RGBtoHSI(Output.rgb).r;
                break;
            case 7:
                Output.a = CColor_RGBtoHSI(Output.rgb).g;
                break;
            case 8:
                Output.a = CColor_RGBtoHSI(Output.rgb).b;
                break;
            default:
                Output.a = 1.0;
                break;
        }
    #endif
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Precalculate our needed LOD for all channels
    float2 TexSize = CMath_GetScreenSizeFromTex(Input.Tex0);
    float LOD = max(0.0, log2(max(TexSize.x, TexSize.y) / _CircleAmount));

    #if SHADER_TOGGLE_MONO
        // Create tiles
        Tile MainTiles = GetTiles(Input.Tex0.xy, _Offset);

        // Get texture information
        float4 Blocks = tex2Dlod(SampleTempTex0, float4(GetBlockTex(MainTiles.Index), 0.0, LOD));
        Blocks.a = (Blocks.a * _InputMultiplier) + _InputBias;

        // Create the UV for the circles
        float CircleDist = GetTileCircleLength(MainTiles);

        // Create the circle
        float Circles = smoothstep(0.89 - fwidth(CircleDist), 0.9, CircleDist + Blocks.a);

        // Mix colors together
        float3 OutputColor = lerp(_FrontColor, _BackColor, Circles);
        OutputColor = lerp(OutputColor, _BackColor, saturate(Blocks.a));

        // Crop the image
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.x > _Crop.x);
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.x < (_CircleAmount - _Crop.y));
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.y > _Crop.z * 2.0);
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.y < (_CircleAmount - _Crop.w * 2.0));
    #else
        // Create per-color tiles
        Tile RedChannel_Tiles = GetTiles(Input.Tex0.xy, _RedChannelOffset);
        Tile GreenChannel_Tiles = GetTiles(Input.Tex0.xy, _GreenChannelOffset);
        Tile BlueChannel_Tiles = GetTiles(Input.Tex0.xy, _BlueChannelOffset);

        // Generate per-color blocks
        float3 Blocks = 0.0;
        Blocks.r = tex2Dlod(SampleTempTex0, float4(GetBlockTex(RedChannel_Tiles.Index), 0.0, LOD)).r;
        Blocks.g = tex2Dlod(SampleTempTex0, float4(GetBlockTex(GreenChannel_Tiles.Index), 0.0, LOD)).g;
        Blocks.b = tex2Dlod(SampleTempTex0, float4(GetBlockTex(BlueChannel_Tiles.Index), 0.0, LOD)).b;
        Blocks = saturate((Blocks * _InputMultiplier) + _InputBias);

        // Generate per-color, circle-shaped lengths of each channel blocks' texture coordinates
        float3 CircleDist = 0.0;
        CircleDist.r = GetTileCircleLength(RedChannel_Tiles);
        CircleDist.g = GetTileCircleLength(GreenChannel_Tiles);
        CircleDist.b = GetTileCircleLength(BlueChannel_Tiles);

        // Initialize variables
        float3 Circles = 0.0;
        float3 OutputColor = 0.0;

        // Generate the per-color circle
        if (_InvertProcessing)
        {
            Circles = smoothstep(0.89 - fwidth(CircleDist), 0.9, CircleDist.rgb + (1.0 - Blocks.rgb));
            OutputColor = lerp(_FrontColor, _BackColor, Circles);
            OutputColor = lerp(_BackColor, OutputColor, saturate(Blocks.rgb));
        }
        else
        {
            Circles = smoothstep(0.89 - fwidth(CircleDist), 0.9, CircleDist + Blocks.rgb);
            OutputColor = lerp(_FrontColor, _BackColor, Circles);
            OutputColor = lerp(OutputColor, _BackColor, saturate(Blocks.rgb));
        }

        // Per-color cropping
        CropChannel(OutputColor.r, 0, RedChannel_Tiles, _RedChannelCrop);
        CropChannel(OutputColor.g, 1, GreenChannel_Tiles, _GreenChannelCrop);
        CropChannel(OutputColor.b, 2, BlueChannel_Tiles, _BlueChannelCrop);
    #endif

    Output = CBlend_OutputChannels(OutputColor, _CShade_AlphaFactor);
}

technique CShade_Dots
<
    ui_label = "CShade / Dots";
    ui_tooltip = "Creates circles based on image features.\n\n[+] This shader has a monotone version (SHADER_TOGGLE_MONO).";
>
{
    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGBA8_8;
    }

    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
