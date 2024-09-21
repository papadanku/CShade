
#include "shared/fidelityfx/cCAS.fxh"

/*
    [Shader Options]
*/

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Mask\0";
> = 0;

uniform int _Kernel <
    ui_category = "Sharpening";
    ui_label = "Kernel Shape";
    ui_type = "combo";
    ui_items = "Diamond\0Box\0";
> = 1;

uniform float _Contrast <
    ui_category = "Sharpening";
    ui_label = "Contrast";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

float4 PS_CAS(CShade_VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float4 OutputMask = 1.0;
    FFX_CAS(
        OutputColor,
        OutputMask,
        Input.Tex0,
        fwidth(Input.Tex0.xy),
        _Kernel,
        _Contrast
    );

    if (_RenderMode == 1)
    {
        OutputColor = OutputMask;
    }

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_CAS < ui_tooltip = "AMD FidelityFX | Contrast Adaptive Sharpening (CAS)"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CAS;
    }
}
