#define CSHADE_DOTS

#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

#ifndef ENABLE_MONO
    #define ENABLE_MONO 0
#endif

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
    ui_max = 256;
> = 128;

uniform float _InputMultiplier <
    ui_category = "Input Color";
    ui_label = "Multiplier";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 8.0;
> = 4.0;

uniform float _InputBias <
    ui_category = "Input Color";
    ui_label = "Bias";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

#if ENABLE_MONO
    uniform float2 _Offset <
        ui_category = "Shaping";
        ui_label = "Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;
#else
    uniform float2 _RedChannelOffset <
        ui_category = "Shaping";
        ui_label = "Red Channel Offset";
        ui_type = "slider";
        ui_step = 0.1;
        ui_min = -10.0;
        ui_max = 10.0;
    > = 0.0;

    uniform float2 _GreenChannelOffset <
        ui_category = "Shaping";
        ui_label = "Green Channel Offset";
        ui_type = "slider";
        ui_step = 0.1;
        ui_min = -10.0;
        ui_max = 10.0;
    > = 0.0;

    uniform float2 _BlueChannelOffset <
        ui_category = "Shaping";
        ui_label = "Blue Channel Offset";
        ui_type = "slider";
        ui_step = 0.1;
        ui_min = -10.0;
        ui_max = 10.0;
    > = 0.0;

    uniform int4 _RedChannelCrop <
        ui_category = "Crop | Left, Right, Top, Bottom";
        ui_label = "Red Channel";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;

    uniform int4 _GreenChannelCrop <
        ui_category = "Crop | Left, Right, Top, Bottom";
        ui_label = "Green Channel";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;

    uniform int4 _BlueChannelCrop <
        ui_category = "Crop | Left, Right, Top, Bottom";
        ui_label = "Blue Channel";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;
#endif

uniform float3 _FrontColor <
    ui_category = "Composition";
    ui_label = "Foreground";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(0.0, 0.0, 0.0);

uniform float3 _BackColor <
    ui_category = "Composition";
    ui_label = "Background";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(1.0, 1.0, 1.0);

#if ENABLE_MONO
    uniform int4 _Crop <
        ui_category = "Composition";
        ui_label = "Crop (Left, Right, Top, Bottom)";
        ui_type = "slider";
        ui_min = 0;
        ui_max = 10;
    > = 0;
#endif

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures and Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex0_RGBA8_8, BUFFER_SIZE_0, RGBA8, 8)
CREATE_SRGB_SAMPLER(SampleTempTex0, TempTex0_RGBA8_8, LINEAR, MIRROR, MIRROR, MIRROR)

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
    Output.Value.x = (CMath_Float1_GetModulus(trunc(Output.Value.y), 2.0) == 1.0) ? Output.Value.x + 0.25: Output.Value.x - 0.25;

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

#if ENABLE_MONO
    float4 PS_Blit(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float4 Color = CShade_BackBuffer2D(Input.Tex0);
        switch(_Select)
        {
            case 0:
                Color.a = CColor_GetHSVfromRGB(Color.rgb).r;
                break;
            case 1:
                Color.a = CColor_GetHSVfromRGB(Color.rgb).g;
                break;
            case 2:
                Color.a = CColor_GetHSVfromRGB(Color.rgb).b;
                break;
            case 3:
                Color.a = CColor_GetHSLfromRGB(Color.rgb).r;
                break;
            case 4:
                Color.a = CColor_GetHSLfromRGB(Color.rgb).g;
                break;
            case 5:
                Color.a = CColor_GetHSLfromRGB(Color.rgb).b;
                break;
            case 6:
                Color.a = CColor_GetHSIfromRGB(Color.rgb).r;
                break;
            case 7:
                Color.a = CColor_GetHSIfromRGB(Color.rgb).g;
                break;
            case 8:
                Color.a = CColor_GetHSIfromRGB(Color.rgb).b;
                break;
            default:
                Color.a = 1.0;
                break;
        }

        return Color;
    }

    float4 PS_Circles(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        // Precalculate our needed LOD for all channels
        float2 TexSize = CShade_GetScreenSizeFromTex(Input.Tex0);
        float LOD = max(0.0, log2(max(TexSize.x, TexSize.y) / _CircleAmount));

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

        return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
    }
#else
    float4 PS_Blit(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        return CShade_BackBuffer2D(Input.Tex0);
    }

    float4 PS_Circles(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        // Precalculate our needed LOD for all channels
        float2 TexSize = CShade_GetScreenSizeFromTex(Input.Tex0);
        float LOD = max(0.0, log2(max(TexSize.x, TexSize.y) / _CircleAmount));

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

        return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
    }
#endif

technique CShade_Dots < ui_tooltip = "Creates circles based on image features"; >
{
    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGBA8_8;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Circles;
    }
}
