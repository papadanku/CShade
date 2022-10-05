
uniform float2 _ShiftRed <
    ui_type = "drag";
> = -1.0;

uniform float2 _ShiftGreen <
    ui_type = "drag";
> = 0.0;

uniform float2 _ShiftBlue <
    ui_type = "drag";
> = 1.0;

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void Abberation_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    // Shift red channel
    OutputColor0.r = tex2D(Sample_Color, TexCoord + _ShiftRed * PixelSize).r;
    // Keep green channel to the center
    OutputColor0.g = tex2D(Sample_Color, TexCoord + _ShiftGreen * PixelSize).g;
    // Shift blue channel
    OutputColor0.b = tex2D(Sample_Color, TexCoord + _ShiftBlue * PixelSize).b;
    // Write alpha value
    OutputColor0.a = 1.0;
}

technique cAbberation
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Abberation_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
