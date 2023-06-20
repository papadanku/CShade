#include "shared/cGraphics.fxh"
#include "shared/cImageProcessing.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_label = "Method";
    ui_tooltip = "Select Chromaticity";
    ui_type = "combo";
    ui_items = " Length (RG)\0 Length (RGB)\0 Average (RG)\0 Average (RGB)\0 Sum (RG)\0 Sum (RGB)\0 Polar (RG)\0";
> = 0;

/*
    [Pixel Shaders]
*/

float4 PS_Chromaticity(VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 Chromaticity = 0.0;

    switch(_Select)
    {
        case 0: // Length (RG)
            Chromaticity.rg = GetChromaticity(Color, 0).rg;
            break;
        case 1: // Length (RGB)
            Chromaticity.rgb = GetChromaticity(Color, 0).rgb;
            break;
        case 2: // Average (RG)
            Chromaticity.rg = GetChromaticity(Color, 1).rg;
            break;
        case 3: // Average (RGB)
            Chromaticity.rgb = GetChromaticity(Color, 1).rgb;
            break;
        case 4: // Sum (RG)
            Chromaticity.rg = GetChromaticity(Color, 2).rg;
            break;
        case 5: // Sum (RGB)
            Chromaticity.rgb = GetChromaticity(Color, 2).rgb;
            break;
        case 6: // Polar (RG)
            Chromaticity.rg = GetPolar(Color);
            break;
        default: // No Chromaticity
            Chromaticity.rgb = 0.0;
            break;
    }

    return float4(Chromaticity, 1.0);
}

technique CShade_Chromaticity
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Chromaticity;
    }
}
