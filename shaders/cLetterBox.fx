
/*
    [Shader Options]
*/

uniform float2 _Offset <
    ui_label = "Letterbox Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = float2(0.0, 0.0);

uniform float2 _Scale <
    ui_label = "Letterbox Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = float2(1.0, 0.8);

#include "shared/cShade.fxh"
#include "shared/cBlendOp.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Letterbox(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    // Output a rectangle
    Input.Tex0 = (Input.Tex0 * 2.0) - 1.0;
    Input.Tex0 += _Offset;
    float2 Shaper = step(abs(Input.Tex0), _Scale);
    return float4(Shaper.xxx * Shaper.yyy, _CShadeAlphaFactor);
}

technique CShade_LetterBox
{
    pass
    {
        // Blend the rectangle with the backbuffer
        SRGBWriteEnable = WRITE_SRGB;
        CBLENDOP_OUTPUT_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Letterbox;
    }
}
