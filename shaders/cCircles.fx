#include "shared/cGraphics.fxh"
#include "shared/cMacros.fxh"

/*
    Construct options
*/

uniform float _TileAmount <
    ui_label = "Amount";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 64.0;
> = 8.0;

uniform float _TileRadius <
    ui_label = "Radius";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 0.5;
> = 0.45;

float2 GetTiles(float2 Tex)
{
    Tex *= _TileAmount;

    // Get tex's row index
    float RowIndex = step(1.0, GetMod(Tex.y, 2.0));

    // Offset every odd row by 0.5
    Tex.x += (RowIndex * 0.5);
    Tex.x = (RowIndex == 1.0) ? -Tex.x : Tex.x;

    return frac(Tex);
}

float4 PS_Circles(VS2PS_Quad Input) : SV_TARGET0
{
    Input.Tex0 = Input.Tex0 * 2.0 - 1.0;

	// Stretch the image to 1:1 aspect ratio
	float2 BSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
	float2 Tex = (Input.Tex0.xy * BSize) / min(BSize.x, BSize.y);

    // Tile data
    float2 TexTiles = GetTiles(Tex);
    float TileDist = distance(TexTiles, 0.5);
    float AntiAlias = fwidth(TileDist);

    // Display data
    float3 Texture = tex2D(CShade_SampleColorTex, TexTiles).rgb;
    float Circles = smoothstep(_TileRadius, _TileRadius - AntiAlias, TileDist);

    return float4(Texture * Circles, 1.0);
}

technique CShade_Circles
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Circles;
    }
}
