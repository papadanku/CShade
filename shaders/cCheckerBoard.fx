#define CSHADE_CHECKERBOARD

/*
    This shader generates a customizable checkerboard pattern. Users can define the size of the squares, invert the pattern, and select two distinct colors for the checkerboard.
*/

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

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 Checkerboard = frac(dot(floor(Input.HPos.xy / _Width), 0.5)) * 2.0;
    Checkerboard = _InvertCheckerboard ? 1.0 - Checkerboard : Checkerboard;
    Checkerboard = Checkerboard == 1.0 ? _Color1 : _Color2;

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Checkerboard, _CShade_AlphaFactor);
    #else
        Output = float4(Checkerboard, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_CheckerBoard
<
    ui_label = "CShade | Checkerboard";
    ui_tooltip = "Adjustable checkerboard effect.";
>
{
    pass Checkerboard
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
