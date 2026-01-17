#define CSHADE_ECLIPSE

/*
    This shader applies lens-related visual effects, inspired by AMD FidelityFX Lens. It simulates film grain, chromatic aberration, and vignetting, allowing users to control their intensity and characteristics. The film grain can be seeded by time for dynamic patterns, and adjustments are available for grain size, amount, chromatic aberration strength, and vignette intensity.

    This shader also implements a standalone color grading effect. It applies various color transformations and adjustments to the backbuffer color, allowing users to modify the overall color and tone of the image. The shader can also optionally apply exposure peaking.
*/

/* Shader Options */

#include "shared/cColor.fxh"

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#define CSHADE_APPLY_GRADING 1
#define CSHADE_APPLY_TONEMAP 1
#define CSHADE_APPLY_PEAKING 1
#include "shared/cShade.fxh"

/* Pixel Shaders */

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Get backbuffer
    float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Color.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Color.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_ColorGrade
<
    ui_label = "CShade | Color Grade";
    ui_tooltip = "Standalone, adjustable color grading.";
>
{
    pass ColorGrade
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
