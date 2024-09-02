
/*
    [Shader Options]
*/

uniform int2 _Pixels <
    ui_label = "Pixel Amount";
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 1024.0;
> = 512.0;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Color(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = floor(Input.Tex0 * _Pixels) / _Pixels;
    float4 OutputColor = tex2D(CShade_SampleColorTex, Tex);

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_Pixelate < ui_tooltip = "Adjustable pixelation effect"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Color;
    }
}
