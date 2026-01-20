#define CSHADE_LETTERBOX

/*
    This shader creates a letterbox effect, adding customizable black bars to the screen to achieve cinematic aspect ratios. Users can adjust the position offset, size scale, and edge sharpness of these letterbox bars.
*/

#include "shared/cMath.fxh"

/* Shader Options */

uniform float2 _Offset <
    ui_label = "Offset";
    ui_max = 1.0;
    ui_min = -1.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the horizontal and vertical position of the letterbox effect on the screen.";
> = float2(0.0, 0.0);

uniform float2 _Scale <
    ui_label = "Scale";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the size of the letterbox, making it larger or smaller.";
> = float2(1.0, 1.0);

uniform float2 _Cutoff <
    ui_label = "Cutoff";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Determines the sharpness of the letterbox edges. Lower values create a softer transition.";
> = float2(1.0, 0.8);

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0 
#include "shared/cShade.fxh"

/* Pixel Shaders */

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Output a rectangle
    float2 ShapeTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
    ShapeTex = (ShapeTex * _Scale) + _Offset;
    float2 Shaper = step(abs(ShapeTex), _Cutoff);

    // RENDER
    float Shape = Shaper.xxx * Shaper.yyy;

    #if defined(CSHADE_BLENDING)
        Output = float4((float3)Shape, _CShade_AlphaFactor);
    #else
        Output = float4((float3)Shape, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
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
#ifndef CBLEND_BLENDOPALPHA
    #define CBLEND_BLENDOPALPHA ADD
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
    ui_label = "CShade | Letterbox";
    ui_tooltip = "Adjustable letterboxing effect.";
>
{
    pass Letterbox
    {
        // Blend the rectangle with the backbuffer
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
