
#include "cGraphics.fxh"

/*
    Construct options
*/

uniform int _Select <
    ui_type = "combo";
    ui_items = " Length (RG)\0 Length (RGB)\0 Average (RG)\0 Average (RGB)\0 Sum (RG)\0 Sum (RGB)\0 Max (RG)\0 Max (RGB)\0";
    ui_label = "Method";
    ui_tooltip = "Select Chromaticity";
> = 0;

// Pixel shaders

float4 PS_Chromaticity(VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = max(tex2D(SampleColorTex, Input.Tex0).rgb, exp2(-10.0));
    float3 Chromaticity = 0.0;

    switch(_Select)
    {
        case 0: // Length (RG)
            Chromaticity.rg = saturate(normalize(Color).rg);
            break;
        case 1: // Length (RGB)
            Chromaticity = saturate(normalize(Color));
            break;
        case 2: // Average (RG)
            Chromaticity.rg = saturate(Color.rg / dot(Color, 1.0 / 3.0));
            break;
        case 3: // Average (RGB)
            Chromaticity = saturate(Color / dot(Color, 1.0 / 3.0));
            break;
        case 4: // Sum (RG)
            Chromaticity.rg = saturate(Color.rg /  dot(Color, 1.0));
            break;
        case 5: // Sum (RGB)
            Chromaticity = saturate(Color / dot(Color, 1.0));
            break;
        case 6: // Max (RG)
            Chromaticity.rg = saturate(Color.rg / max(max(Color.r, Color.g), Color.b));
            break;
        case 7: // Max (RGB)
            Chromaticity = saturate(Color / max(max(Color.r, Color.g), Color.b));
            break;
        default: // No Chromaticity
            Chromaticity = 0.0;
            break;
    }

    return float4(Chromaticity, 1.0);
}

technique cChromaticity
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Chromaticity;
    }
}
