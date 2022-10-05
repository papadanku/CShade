
uniform int _Select <
    ui_type = "combo";
    ui_items = " Length (RG)\0 Length (RGB)\0 Average (RG)\0 Average (RGB)\0 Sum (RG)\0 Sum (RGB)\0 Max (RG)\0 Max (RGB)\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Chromaticity";
> = 0;

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

void Normalization_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = 0.0;
    float3 Color = max(tex2D(Sample_Color, TexCoord).rgb, exp2(-10.0));
    switch(_Select)
    {
        case 0: // Length (RG)
            OutputColor0.rg = saturate(normalize(Color).rg);
            break;
        case 1: // Length (RGB)
            OutputColor0 = saturate(normalize(Color));
            break;
        case 2: // Average (RG)
            OutputColor0.rg = saturate(Color.rg / dot(Color, 1.0 / 3.0));
            break;
        case 3: // Average (RGB)
            OutputColor0 = saturate(Color / dot(Color, 1.0 / 3.0));
            break;
        case 4: // Sum (RG)
            OutputColor0.rg = saturate(Color.rg /  dot(Color, 1.0));
            break;
        case 5: // Sum (RGB)
            OutputColor0 = saturate(Color / dot(Color, 1.0));
            break;
        case 6: // Max (RG)
            OutputColor0.rg = saturate(Color.rg / max(max(Color.r, Color.g), Color.b));
            break;
        case 7: // Max (RGB)
            OutputColor0 = saturate(Color / max(max(Color.r, Color.g), Color.b));
            break;
        default:
            // No Chromaticity
            OutputColor0 = Color;
            break;
    }
}

technique cColorNormalization
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Normalization_PS;
    }
}
