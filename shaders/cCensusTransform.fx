
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

void CensusTransform_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
{
    float2 LocalTexCoord = 0.0;
    LocalTexCoord.x = (ID == 2) ? 2.0 : 0.0;
    LocalTexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(LocalTexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // Sample locations:
    // [0].xy [1].xy [2].xy
    // [0].xz [1].xz [2].xz
    // [0].xw [1].xw [2].xw
    const float2 PixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoords[0] = LocalTexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    TexCoords[1] = LocalTexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    TexCoords[2] = LocalTexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
}

void CensusTransform_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = 0.0;

    const int Neighbors = 8;

    float4 CenterSample = tex2D(Sample_Color, TexCoords[1].xz);

    float4 SampleNeighbor[8];
    SampleNeighbor[0] = tex2D(Sample_Color, TexCoords[0].xy);
    SampleNeighbor[1] = tex2D(Sample_Color, TexCoords[1].xy);
    SampleNeighbor[2] = tex2D(Sample_Color, TexCoords[2].xy);
    SampleNeighbor[3] = tex2D(Sample_Color, TexCoords[0].xz);
    SampleNeighbor[4] = tex2D(Sample_Color, TexCoords[2].xz);
    SampleNeighbor[5] = tex2D(Sample_Color, TexCoords[0].xw);
    SampleNeighbor[6] = tex2D(Sample_Color, TexCoords[1].xw);
    SampleNeighbor[7] = tex2D(Sample_Color, TexCoords[2].xw);
    
    // Generate 8-bit integer from the 8-pixel neighborhood
    for(int i = 0; i < Neighbors; i++)
    {
        float4 Comparison = step(SampleNeighbor[i], CenterSample);
        OutputColor0 += ldexp(Comparison, i);
    }

	// Convert the 8-bit integer to float, and average the results from each channel
    OutputColor0 = saturate(dot(OutputColor0.rgb * (1.0 / (exp2(8) - 1)), 1.0 / 3.0));
}

technique cCensusTransform
{
    pass
    {
        VertexShader = CensusTransform_VS;
        PixelShader = CensusTransform_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
