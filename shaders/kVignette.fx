#include "shared/cGraphics.fxh"
#include "shared/cCamera.fxh"

/*
    [Shader Options]
*/

uniform float _Falloff <
    ui_label = "Falloff";
    ui_type = "drag";
> = 0.5;

/*
    [Pixel Shaders]
*/

float4 PS_Vignette(VS2PS_Quad Input) : SV_TARGET0
{
    const float AspectRatio = float(BUFFER_WIDTH) / float(BUFFER_HEIGHT);
    return GetVignette(Input.Tex0, AspectRatio, _Falloff);
}

technique CShade_KinoVignette
{
    pass
    {
        // Multiplication blend mode
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Vignette;
    }
}
