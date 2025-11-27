#define CSHADE_LETTERBOX

#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform float2 _Offset <
    ui_category = "Main Shader";
    ui_label = "Letterbox Position Offset";
    ui_max = 1.0;
    ui_min = -1.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the horizontal and vertical position of the letterbox effect on the screen.";
> = float2(0.0, 0.0);

uniform float2 _Scale <
    ui_category = "Main Shader";
    ui_label = "Letterbox Size Scale";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the size of the letterbox, making it larger or smaller.";
> = float2(1.0, 1.0);

uniform float2 _Cutoff <
    ui_category = "Main Shader";
    ui_label = "Letterbox Edge Sharpness";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Determines the sharpness of the letterbox edges. Lower values create a softer transition.";
> = 1.0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Output a rectangle
    Input.Tex0 = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
    Input.Tex0 = (Input.Tex0 * _Scale) + _Offset;
    float2 Shaper = step(abs(Input.Tex0), _Cutoff);

    Output = CBlend_OutputChannels(Shaper.xxx * Shaper.yyy, _CShade_AlphaFactor);
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

technique CShade_LetterBox
<
    ui_label = "CShade / Letterbox";
    ui_tooltip = "Adjustable letterboxing effect.";
>
{
    pass
    {
        // Blend the rectangle with the backbuffer
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
