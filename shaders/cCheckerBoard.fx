#define CSHADE_CHECKERBOARD

#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform bool _InvertCheckerboard <
    ui_category = "Main Shader";
    ui_label = "Invert Pattern";
    ui_type = "radio";
    ui_tooltip = "Reverses the pattern of the checkerboard, swapping the positions of Color 1 and Color 2.";
> = false;

uniform int _Width <
    ui_category = "Main Shader";
    ui_label = "Grid Size";
    ui_max = 16;
    ui_min = 1;
    ui_type = "slider";
    ui_tooltip = "Sets the size of each square in the checkerboard pattern. Smaller values create more squares.";
> = 4;

uniform float3 _Color1 <
    ui_category = "Main Shader";
    ui_label = "First Color";
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Defines the first color used in the checkerboard pattern.";
> = 1.0;

uniform float3 _Color2 <
    ui_category = "Main Shader";
    ui_label = "Second Color";
    ui_min = 0.0;
    ui_type = "color";
    ui_tooltip = "Defines the second color used in the checkerboard pattern.";
> = 0.0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 Checkerboard = frac(dot(floor(Input.HPos.xy / _Width), 0.5)) * 2.0;
    Checkerboard = _InvertCheckerboard ? 1.0 - Checkerboard : Checkerboard;
    Checkerboard = Checkerboard == 1.0 ? _Color1 : _Color2;

    Output = CBlend_OutputChannels(Checkerboard, _CShade_AlphaFactor);
}

technique CShade_CheckerBoard
<
    ui_label = "CShade / Checkerboard";
    ui_tooltip = "Adjustable checkerboard effect.";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
