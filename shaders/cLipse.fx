#define CSHADE_GRADING

/*
    [Shader Options]
*/

#include "shared/cShadeHDR.fxh"
#include "shared/cColor.fxh"

#define CCAMERA_TOGGLE_AUTO_EXPOSURE 0
#define CCAMERA_TOGGLE_EXPOSURE_PEAKING 1
#include "shared/cCamera.fxh"

#include "shared/cComposite.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Get backbuffer
    float4 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0);

    // Apply color grading
    CComposite_ApplyOutput(Color.rgb);

    // Apply exposure peaking to areas that need it
    CCAmera_ApplyExposurePeaking(Color, Input.HPos.xy);

    // Our epic output
    Output = CBlend_OutputChannels(Color, _CShade_AlphaFactor);
}

technique CShade_Grading
<
    ui_label = "CShade / Color Grade";
    ui_tooltip = "Standalone, adjustable color grading effect.";
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
