
uniform float2 _Scale <
    ui_min = 0.0;
    ui_label = "Scale";
    ui_type = "drag";
> = float2(1.0, 0.8);

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void Letterbox_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor : SV_TARGET0)
{
    // Output a rectangle
    const float2 Scale = -_Scale * 0.5 + 0.5;
    float2 Shaper  = step(Scale, TexCoord);
           Shaper *= step(Scale, 1.0 - TexCoord);
    OutputColor = Shaper.xxxx * Shaper.yyyy;
}

technique cLetterBox
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Letterbox_PS;
        // Blend the rectangle with the backbuffer
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
