
uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Mask\0";
> = 0;

uniform float _Sharpening <
    ui_category = "Robust Contrast Adaptive Sharpening";
    ui_label = "Sharpening";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

#include "shared/fidelityfx/cRCAS.fxh"

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

float4 PS_CasFilterNoScaling(CShade_VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float4 OutputMask = 1.0;
    FFX_RCAS(
        OutputColor,
        OutputMask,
        Input.Tex0,
        fwidth(Input.Tex0.xy),
        _Sharpening
    );

    if (_RenderMode == 1)
    {
        OutputColor = OutputMask;
    }

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_ImageSharpen < ui_tooltip = "FidelityFX | Robust Contrast Adaptive Sharpening (RCAS)"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CasFilterNoScaling;
    }
}
