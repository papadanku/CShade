
/*
    [Shader Options]
*/

uniform float _Angle <
    ui_label = "Rotation Angle";
    ui_type = "drag";
> = 0.0;

uniform float2 _Translate <
    ui_label = "Translation";
    ui_type = "drag";
> = 0.0;

uniform float2 _Scale <
    ui_label = "Scaling";
    ui_type = "drag";
> = 1.0;

#ifndef BACKBUFFER_ADDRESSU
    #define BACKBUFFER_ADDRESSU CLAMP
#endif
#ifndef BACKBUFFER_ADDRESSV
    #define BACKBUFFER_ADDRESSV CLAMP
#endif
#ifndef BACKBUFFER_ADDRESSW
    #define BACKBUFFER_ADDRESSW CLAMP
#endif

#include "shared/cMath.fxh"

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

CREATE_SRGB_SAMPLER(SampleTransformTex, CShade_ColorTex, LINEAR, BACKBUFFER_ADDRESSU, BACKBUFFER_ADDRESSV, BACKBUFFER_ADDRESSW)

/*
    [Vertex Shaders]
*/

CShade_VS2PS_Quad VS_Matrix(CShade_APP2VS Input)
{
    // Calculate the shader's HPos and Tex0
    // We modify the Tex0's output afterward
    CShade_VS2PS_Quad Output = CShade_VS_Quad(Input);
    float Pi2 = CMath_GetPi() * 2.0;
    Output.Tex0 = CMath_Transform2D(Output.Tex0, _Angle * Pi2, _Translate, _Scale);

    return Output;
}

/*
    [Pixel Shaders]
*/

float4 PS_Matrix(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(SampleTransformTex, Input.Tex0);
    return CBlend_OutputChannels(float4(Color.rgb, _CShadeAlphaFactor));
}

technique CShade_Transform
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = VS_Matrix;
        PixelShader = PS_Matrix;
    }
}
