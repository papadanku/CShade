
// Vertex shaders

void Basic_VS(out float4 Position : SV_POSITION)
{
    Position = 0.0;
}

// Pixel shaders

void Basic_PS(out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = 0.0;
}

technique cDefault
{
    pass
    {
        VertexCount = 0;
        VertexShader = Basic_VS;
        PixelShader = Basic_PS;
    }
}
