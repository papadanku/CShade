#define CSHADE_LETTERBOX

/*
    [Shader Options]
*/

uniform float2 _Offset <
    ui_label = "Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = float2(0.0, 0.0);

uniform float2 _Scale <
    ui_label = "Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = float2(1.0, 1.0);

uniform float2 _Cutoff <
    ui_label = "Cutoff";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Letterbox(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    // Output a rectangle
    Input.Tex0 = (Input.Tex0 * 2.0) - 1.0;
    Input.Tex0 = (Input.Tex0 * _Scale) + _Offset;
    float2 Shaper = step(abs(Input.Tex0), _Cutoff);
    return CBlend_OutputChannels(float4(Shaper.xxx * Shaper.yyy, _CShadeAlphaFactor));
}

#undef CBLEND_BLENDENABLE
#undef CBLEND_BLENDOP
#undef CBLEND_SRCBLEND
#undef CBLEND_SRCBLENDALPHA
#undef CBLEND_DESTBLEND
#undef CBLEND_DESTBLENDALPHA
#ifndef CBLEND_BLENDENABLE
    #define CBLEND_BLENDENABLE TRUE
#endif
#ifndef CBLEND_BLENDOP
    #define CBLEND_BLENDOP ADD
#endif
#ifndef CBLEND_SRCBLEND
    #define CBLEND_SRCBLEND DESTCOLOR
#endif
#ifndef CBLEND_SRCBLENDALPHA
    #define CBLEND_SRCBLENDALPHA SRCALPHA
#endif
#ifndef CBLEND_DESTBLEND
    #define CBLEND_DESTBLEND ZERO
#endif
#ifndef CBLEND_DESTBLENDALPHA
    #define CBLEND_DESTBLENDALPHA ZERO
#endif

technique CShade_LetterBox < ui_tooltip = "Adjustable letterboxing effect"; >
{
    pass
    {
        // Blend the rectangle with the backbuffer
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Letterbox;
    }
}
