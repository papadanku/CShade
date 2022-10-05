
uniform float _TimeRate <
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_tooltip = "Exposure time smoothing";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.95;

uniform float _ManualBias <
    ui_label = "Exposure";
    ui_type = "drag";
    ui_tooltip = "Optional manual bias ";
    ui_min = 0.0;
> = 2.0;

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

texture2D Render_Luma_LOD
{
    Width = 256;
    Height = 256;
    MipLevels = 9;
    Format = R16F;
};

sampler2D Sample_Luma_LOD
{
    Texture = Render_Luma_LOD;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders
// TODO: Add average, spot, and center-weighted metering with adjustable radius and slope

void Blit_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 Color = tex2D(Sample_Color, TexCoord);

    // OutputColor0.rgb = Output the highest brightness out of red/green/blue component
    // OutputColor0.a = Output the weight for temporal blending
    OutputColor0 = float4(max(Color.r, max(Color.g, Color.b)).rrr, _TimeRate);
}

void Exposure_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    // Average Luma = Average value (1x1) for all of the pixels
    float AverageLuma = tex2Dlod(Sample_Luma_LOD, float4(TexCoord, 0.0, 8.0)).r;
    float4 Color = tex2D(Sample_Color, TexCoord);

    // KeyValue is an exposure compensation curve
    // Source: https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
    float KeyValue = 1.03 - (2.0 / (log10(AverageLuma + 1.0) + 2.0));
    float ExposureValue = log2(KeyValue / AverageLuma) + _ManualBias;
    OutputColor0 = Color * exp2(ExposureValue);
}

technique cAutoExposure
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Blit_PS;
        RenderTarget = Render_Luma_LOD;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Exposure_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
