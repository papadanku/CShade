
uniform float _Weight <
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

void Shard_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0, out float4 Offset : TEXCOORD1)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    const float2 PixelSize = 0.5 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    Offset = TexCoord.xyxy + float4(-PixelSize, PixelSize);
}

/* [ Pixel Shaders ] */

void Shard_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, in float4 Offset : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    float4 OriginalSample = tex2D(Sample_Color, TexCoord);
    float4 BlurSample = 0.0;
    BlurSample += tex2D(Sample_Color, Offset.xw) * 0.25;
    BlurSample += tex2D(Sample_Color, Offset.zw) * 0.25;
    BlurSample += tex2D(Sample_Color, Offset.xy) * 0.25;
    BlurSample += tex2D(Sample_Color, Offset.zy) * 0.25;
    OutputColor0 = OriginalSample + (OriginalSample - BlurSample) * _Weight;
}

technique cShard
{
    pass
    {
        VertexShader = Shard_VS;
        PixelShader = Shard_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
