
#include "shared/cGraphics.fxh"
#include "shared/cMacros.fxh"
#include "shared/cColorSpaces.fxh"

sampler2D CShade_SampleColorTexMirror
{
    Texture = CShade_ColorTex;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = READ_SRGB;
};

/*
    [Shader Options]
*/

#ifndef ENABLE_MONO
    #define ENABLE_MONO 0
#endif

#define MAX_CIRCLES GET_MIN(BUFFER_WIDTH, BUFFER_HEIGHT) / 10

#if !ENABLE_MONO
    uniform bool _InvertProcessing <
        ui_label = "Invert Processing";
        ui_type = "radio";
    > = false;
#endif

#if ENABLE_MONO
    uniform int _Select <
        ui_label = "Search Feature";
        ui_type = "combo";
        ui_items = "HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
    > = 2;
#endif

uniform int _CircleAmount <
    ui_label = "Number of Circles";
    ui_type = "slider";
    ui_min = 1;
    ui_max = MAX_CIRCLES;
> = MAX_CIRCLES / 2;

uniform float _InputMultiplier <
    ui_category = "Input";
    ui_label = "Multiplier";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 8.0;
> = 4.0;

uniform float _InputBias <
    ui_category = "Input";
    ui_label = "Bias";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

#if ENABLE_MONO
    uniform float2 _Offset <
        ui_category = "Circles";
        ui_label = "Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;
#else
    uniform float2 _RedChannel_Offset <
        ui_category = "Offset";
        ui_label = "Red Channel";
        ui_type = "slider";
        ui_step = 0.1;
        ui_min = -10.0;
        ui_max = 10.0;
    > = 0.0;

    uniform float2 _GreenChannel_Offset <
        ui_category = "Offset";
        ui_label = "Green Channel";
        ui_type = "slider";
        ui_step = 0.1;
        ui_min = -10.0;
        ui_max = 10.0;
    > = 0.0;

    uniform float2 _BlueChannel_Offset <
        ui_category = "Offset";
        ui_label = "Blue Channel";
        ui_type = "slider";
        ui_step = 0.1;
        ui_min = -10.0;
        ui_max = 10.0;
    > = 0.0;

    uniform int4 _RedChannel_Crop <
        ui_category = "Crop (Left, Right, Top, Bottom)";
        ui_label = "Red Channel";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;

    uniform int4 _GreenChannel_Crop <
        ui_category = "Crop (Left, Right, Top, Bottom)";
        ui_label = "Green Channel";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;

    uniform int4 _BlueChannel_Crop <
        ui_category = "Crop (Left, Right, Top, Bottom)";
        ui_label = "Blue Channel";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;
#endif

uniform float3 _FrontColor <
    ui_category = "Output";
    ui_label = "Foreground";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(0.0, 0.0, 0.0);

uniform float3 _BackColor <
    ui_category = "Output";
    ui_label = "Background";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(1.0, 1.0, 1.0);

#if ENABLE_MONO
    uniform int4 _Crop <
        ui_category = "Output";
        ui_label = "Crop (Left, Right, Top, Bottom)";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;
#endif

/*
    [Textures and Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex0_RGBA8, BUFFER_SIZE_0, RGBA8, 8)
CREATE_SRGB_SAMPLER(SampleTempTex0, TempTex0_RGBA8, LINEAR, MIRROR)

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
    Output.Value.x = (GetMod(trunc(Output.Value.y), 2.0) == 1.0) ? Output.Value.x + 0.25: Output.Value.x - 0.25;

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
    float2 CircleTiles = (Input.Frac * 2.0) - 1.0;
    // Shrink the UV so [-1, 1] fills a square
    #if BUFFER_WIDTH > BUFFER_HEIGHT
        CircleTiles.x *= ASPECT_RATIO;
    #else
        CircleTiles.y *= ASPECT_RATIO;
    #endif

    return length(CircleTiles);
}

#if !ENABLE_MONO
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

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    return tex2D(CShade_SampleColorTex, Input.Tex0);
}

#if ENABLE_MONO
    float4 PS_Circles(VS2PS_Quad Input) : SV_TARGET0
    {
        // Precalculate our needed LOD for all channels
        float2 TexSize = GetScreenSizeFromTex(Input.Tex0);
        float LOD = max(0.0, log2(max(TexSize.x, TexSize.y) / _CircleAmount));

        // Create tiles
        Tile MainTiles = GetTiles(Input.Tex0.xy, _Offset);

        // Get texture information
        float4 Blocks = tex2Dlod(SampleTempTex0, float4(GetBlockTex(MainTiles.Index), 0.0, LOD));
        Blocks = (Blocks * _InputMultiplier) + _InputBias;

        float Feature = 0.0;

        switch(_Select)
        {
            case 0:
                Feature = GetHSVfromRGB(Blocks.rgb).r;
                break;
            case 1:
                Feature = GetHSVfromRGB(Blocks.rgb).g;
                break;
            case 2:
                Feature = GetHSVfromRGB(Blocks.rgb).b;
                break;
            case 3:
                Feature = GetHSLfromRGB(Blocks.rgb).r;
                break;
            case 4:
                Feature = GetHSLfromRGB(Blocks.rgb).g;
                break;
            case 5:
                Feature = GetHSLfromRGB(Blocks.rgb).b;
                break;
            case 6:
                Feature = GetHSIfromRGB(Blocks.rgb).r;
                break;
            case 7:
                Feature = GetHSIfromRGB(Blocks.rgb).g;
                break;
            case 8:
                Feature = GetHSIfromRGB(Blocks.rgb).b;
                break;
            default:
                Feature = 0.0;
                break;
        }

        // Create the UV for the circles
        float CircleDist = GetTileCircleLength(MainTiles);

        // Create the circle
        float Circles = smoothstep(0.89 - fwidth(CircleDist), 0.9, CircleDist + Feature);

        // Mix colors together
        float3 OutputColor = lerp(_FrontColor, _BackColor, Circles);
        OutputColor = lerp(OutputColor, _BackColor, saturate(Feature));

        // Crop the image
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.x > _Crop.x);
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.x < (_CircleAmount - _Crop.y));
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.y > _Crop.z * 2.0);
        OutputColor = lerp(_BackColor, OutputColor, MainTiles.Value.y < (_CircleAmount - _Crop.w * 2.0));

        return float4(OutputColor.rgb, 1.0);
    }
#else
    float4 PS_Circles(VS2PS_Quad Input) : SV_TARGET0
    {
        // Precalculate our needed LOD for all channels
        float2 TexSize = GetScreenSizeFromTex(Input.Tex0);
        float LOD = max(0.0, log2(max(TexSize.x, TexSize.y) / _CircleAmount));

        // Create per-color tiles
        Tile RedChannel_Tiles = GetTiles(Input.Tex0.xy, _RedChannel_Offset);
        Tile GreenChannel_Tiles = GetTiles(Input.Tex0.xy, _GreenChannel_Offset);
        Tile BlueChannel_Tiles = GetTiles(Input.Tex0.xy, _BlueChannel_Offset);

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
        CropChannel(OutputColor.r, 0, RedChannel_Tiles, _RedChannel_Crop);
        CropChannel(OutputColor.g, 1, GreenChannel_Tiles, _GreenChannel_Crop);
        CropChannel(OutputColor.b, 2, BlueChannel_Tiles, _BlueChannel_Crop);

        return float4(OutputColor, 1.0);
    }
#endif

technique CShade_Circles
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGBA8;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Circles;
    }
}
