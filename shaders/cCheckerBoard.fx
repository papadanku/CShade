
uniform float4 _Color1 <
    ui_min = 0.0;
    ui_label = "Color 1";
    ui_type = "color";
> = 1.0;

uniform float4 _Color2 <
    ui_min = 0.0;
    ui_label = "Color 2";
    ui_type = "color";
> = 0.0;

uniform bool _InvertCheckerboard <
    ui_type = "radio";
    ui_label = "Invert Checkerboard Pattern";
> = false;

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void Checkerboard_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 Checkerboard = frac(dot(Position.xy, 0.5)) * 2.0;
    Checkerboard = _InvertCheckerboard ? 1.0 - Checkerboard : Checkerboard;
    OutputColor0 = Checkerboard == 1.0 ? _Color1 : _Color2;
}

technique cCheckerBoard
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Checkerboard_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
