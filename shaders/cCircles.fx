
#include "shared/cGraphics.fxh"
#include "shared/cMacros.fxh"

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

#define MAX_CIRCLES GET_MIN(BUFFER_WIDTH, BUFFER_HEIGHT) / 10

uniform int _CircleAmount <
    ui_category = "Circles";
    ui_label = "Number";
    ui_type = "slider";
    ui_min = 1;
    ui_max = MAX_CIRCLES;
> = MAX_CIRCLES / 2;

uniform float2 _RedChannel_Offset <
    ui_category = "Offset";
    ui_label = "Red Channel";
    ui_type = "slider";
    ui_min = -10.0;
    ui_max = 10.0;
> = 0.0;

uniform float2 _GreenChannel_Offset <
    ui_category = "Offset";
    ui_label = "Green Channel";
    ui_type = "slider";
    ui_min = -10.0;
    ui_max = 10.0;
> = 0.0;

uniform float2 _BlueChannel_Offset <
    ui_category = "Offset";
    ui_label = "Blue Channel";
    ui_type = "slider";
    ui_min = -10.0;
    ui_max = 10.0;
> = 0.0;

uniform float3 _FrontColor <
    ui_category = "Output";
    ui_label = "Foreground Weights";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(0.0, 0.0, 0.0);

uniform float3 _BackColor <
    ui_category = "Output";
    ui_label = "Background Weights";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(1.0, 1.0, 1.0);

/*
    [Textures and Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex0_RGB10A2, BUFFER_SIZE_0, RGB10A2, 8)
CREATE_SAMPLER(SampleTempTex0, TempTex0_RGB10A2, LINEAR, MIRROR)

/*
    [Pixel Shaders]
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

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    return tex2D(CShade_SampleGammaTex, Input.Tex0);
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

float4 PS_Circles(VS2PS_Quad Input) : SV_TARGET0
{
    // Precalculate our needed LOD for all channels
    float2 TexSize = GetScreenSizeFromTex(Input.Tex0);
    float LOD = max(0.0, log2(max(TexSize.x, TexSize.y) / _CircleAmount));

    // Create per-channel tiles
    Tile RedChannel_Tiles = GetTiles(Input.Tex0.xy, _RedChannel_Offset);
    Tile GreenChannel_Tiles = GetTiles(Input.Tex0.xy, _GreenChannel_Offset);
    Tile BlueChannel_Tiles = GetTiles(Input.Tex0.xy, _BlueChannel_Offset);

    // Generate per-channel blocks
    float4 Blocks = 0.0;
    Blocks.r = tex2Dlod(SampleTempTex0, float4(GetBlockTex(RedChannel_Tiles.Index), 0.0, LOD)).r;
    Blocks.g = tex2Dlod(SampleTempTex0, float4(GetBlockTex(GreenChannel_Tiles.Index), 0.0, LOD)).g;
    Blocks.b = tex2Dlod(SampleTempTex0, float4(GetBlockTex(BlueChannel_Tiles.Index), 0.0, LOD)).b;

    // Generate per-channel, circle-shaped lengths of each channel blocks' texture coordinates
    float3 CircleDist = 0.0;
    CircleDist.r = GetTileCircleLength(RedChannel_Tiles);
    CircleDist.g = GetTileCircleLength(GreenChannel_Tiles);
    CircleDist.b = GetTileCircleLength(BlueChannel_Tiles);

    // Generate the per-color circle
    float3 FeatureFactor = lerp(0.5, 1.0, Blocks.rgb);
    float3 Circles = smoothstep(0.8 * (1.0 - FeatureFactor), 0.5, CircleDist * FeatureFactor);

    // Process OutputColor
    float3 OutputColor = lerp(_FrontColor, _BackColor, Circles);
    OutputColor = lerp(OutputColor, _BackColor, saturate(Blocks.rgb));

    return float4(OutputColor.rgb, 1.0);
}

technique CShade_Circles
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGB10A2;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Circles;
    }
}
