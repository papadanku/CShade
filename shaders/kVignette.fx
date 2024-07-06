
#include "shared/cGraphics.fxh"
#include "shared/cCamera.fxh"

/*
    [Shader Options]
*/

uniform float _Falloff <
    ui_label = "Falloff Scale";
    ui_type = "drag";
> = 0.5;

uniform float2 _FalloffOffset <
    ui_label = "Falloff Offset";
    ui_type = "slider";
    ui_step = 0.001;
    ui_min = -1.0;
    ui_max = 1.0;
> = float2(0.0, 0.0);

/*
    [Pixel Shaders]
*/

float4 PS_Vignette(VS2PS_Quad Input) : SV_TARGET0
{
    const float AspectRatio = float(BUFFER_WIDTH) / float(BUFFER_HEIGHT);
    return GetVignette(Input.Tex0, AspectRatio, _Falloff, _FalloffOffset);
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
