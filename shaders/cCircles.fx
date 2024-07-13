
#include "shared/cGraphics.fxh"
#include "shared/cMacros.fxh"
#include "shared/cColorSpaces.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_label = "Search Feature";
    ui_type = "combo";
    ui_items = "HSV: Hue\0HSV: Saturation\0HSV: Value\0HSL: Hue\0HSL: Saturation\0HSL: Lightness\0HSI: Hue\0HSI: Saturation\0HSI: Intensity\0";
> = 2;

uniform int _CircleAmount <
    ui_label = "Number of Circles";
    ui_type = "slider";
    ui_min = 1;
    ui_max = 100;
> = 50;

uniform float3 _FrontColor <
    ui_label = "Foreground Color";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(1.0, 1.0, 1.0);

uniform float3 _BackColor <
    ui_label = "Background Color";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = float3(0.0, 0.0, 0.0);


/*
    [Pixel Shaders]
*/

float4 PS_Circles(VS2PS_Quad Input) : SV_TARGET0
{
    // Shrink the UV so [-1, 1] fills a square
    float2 Tiles = (Input.Tex0.xy * _CircleAmount);
    float2 Tex = floor(Tiles) / _CircleAmount;

    // Get pixelated color information
    float4 Color = tex2D(CShade_SampleColorTex, Tex);
    float Feature = 0.0;

    switch(_Select)
    {
        case 0:
            Feature = GetHSVfromRGB(Color.rgb).r;
            break;
        case 1:
            Feature = GetHSVfromRGB(Color.rgb).g;
            break;
        case 2:
            Feature = GetHSVfromRGB(Color.rgb).b;
            break;
        case 3:
            Feature = GetHSLfromRGB(Color.rgb).r;
            break;
        case 4:
            Feature = GetHSLfromRGB(Color.rgb).g;
            break;
        case 5:
            Feature = GetHSLfromRGB(Color.rgb).b;
            break;
        case 6:
            Feature = GetHSIfromRGB(Color.rgb).r;
            break;
        case 7:
            Feature = GetHSIfromRGB(Color.rgb).g;
            break;
        case 8:
            Feature = GetHSIfromRGB(Color.rgb).b;
            break;
        default:
            Feature = 0.0;
            break;
    }

    // Create the UV for the circles
    float2 CircleTiles = frac(Tiles) * 2.0 - 1.0;
    // Shrink the UV so [-1, 1] fills a square
    #if BUFFER_WIDTH > BUFFER_HEIGHT
        CircleTiles.x *= ASPECT_RATIO;
    #else
        CircleTiles.y *= ASPECT_RATIO;
    #endif
    float CircleDist = length(CircleTiles);

    // Create the circle
    float FeatureFactor = lerp(0.5, 1.0, Feature);
    float Circles = smoothstep(0.8 * (1.0 - FeatureFactor), 0.5, CircleDist * FeatureFactor);

    // Mix colors together
    float3 OutputColor = lerp(_FrontColor, _BackColor, Circles);
    OutputColor = lerp(OutputColor, _BackColor, Feature);

    return float4(OutputColor, 1.0);
}

technique CShade_Circles
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Circles;
    }
}
