
uniform int _Select <
    ui_type = "combo";
    ui_items = " Average\0 Sum\0 Min\0 Median\0 Max\0 Length\0 Clamped Length\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Luminance";
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

void Luminance_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 Color = tex2D(Sample_Color, TexCoord);
    switch(_Select)
    {
        case 0:
            // Average
            OutputColor0 = dot(Color.rgb, 1.0 / 3.0);
            break;
        case 1:
            // Sum
            OutputColor0 = dot(Color.rgb, 1.0);
            break;
        case 2:
            // Min
            OutputColor0 = min(Color.r, min(Color.g, Color.b));
            break;
        case 3:
            // Median
            OutputColor0 = max(min(Color.r, Color.g), min(max(Color.r, Color.g), Color.b));
            break;
        case 4:
            // Max
            OutputColor0 = max(Color.r, max(Color.g, Color.b));
            break;
        case 5:
            // Length
            OutputColor0 = length(Color.rgb);
            break;
        case 6:
            // Clamped Length
            OutputColor0 = length(Color.rgb) * rsqrt(3.0);
            break;
        default:
            OutputColor0 = Color;
            break;
    }
}

technique cLuminance
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Luminance_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
