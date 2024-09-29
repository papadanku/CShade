#define CSHADE_CHECKERBOARD

#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform int _Width <
    ui_label = "Checkerboard Width";
    ui_type = "slider";
    ui_min = 1;
    ui_max = 16;
> = 4;

uniform float3 _Color1 <
    ui_label = "Color 1";
    ui_type = "color";
    ui_min = 0.0;
> = 1.0;

uniform float3 _Color2 <
    ui_label = "Color 2";
    ui_type = "color";
    ui_min = 0.0;
> = 0.0;

uniform bool _InvertCheckerboard <
    ui_label = "Invert Checkerboard Pattern";
    ui_type = "radio";
> = false;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Checkerboard(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Checkerboard = frac(dot(floor(Input.HPos.xy / _Width), 0.5)) * 2.0;
    Checkerboard = _InvertCheckerboard ? 1.0 - Checkerboard : Checkerboard;
    Checkerboard = Checkerboard == 1.0 ? _Color1 : _Color2;

    return CBlend_OutputChannels(float4(Checkerboard, _CShadeAlphaFactor));
}

technique CShade_CheckerBoard < ui_tooltip = "Adjustable checkerboard effect"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Checkerboard;
    }
}
