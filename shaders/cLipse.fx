#define CSHADE_ECLIPSE

/*
    This shader applies lens-related visual effects, inspired by AMD FidelityFX Lens. It simulates film grain, chromatic aberration, and vignetting, allowing users to control their intensity and characteristics. The film grain can be seeded by time for dynamic patterns, and adjustments are available for grain size, amount, chromatic aberration strength, and vignette intensity.

    This shader also implements a standalone color grading effect. It applies various color transformations and adjustments to the backbuffer color, allowing users to modify the overall color and tone of the image. The shader can also optionally apply exposure peaking.
*/

/*
    [Shader Options]
*/

#include "shared/cColor.fxh"
#include "shared/cShadeHDR.fxh"

// Inject cComposite.fxh
#ifndef SHADER_TOGGLE_PEAKING
    #define SHADER_TOGGLE_PEAKING 0
#endif
#define CCOMPOSITE_TOGGLE_GRADING 1
#define CCOMPOSITE_TOGGLE_TONEMAP 1
#define CCOMPOSITE_TOGGLE_PEAKING SHADER_TOGGLE_PEAKING
#include "shared/cComposite.fxh"

#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Get backbuffer
    float3 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0).rgb;

    // Apply color grading
    CComposite_ApplyOutput(Color.rgb);

    // Apply exposure peaking to areas that need it
    CComposite_ApplyExposurePeaking(Color, Input.HPos.xy);

    // Our epic output
    Output = CBlend_OutputChannels(Color, _CShade_AlphaFactor);
}

technique CShade_Grading
<
    ui_label = "CShade / Color Grade [?]";
    ui_tooltip = "Standalone, adjustable color grading.\n\n[?] This shader has optional exposure peaking display (SHADER_TOGGLE_PEAKING).";
>
{
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
