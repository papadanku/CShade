
#include "shared/cShade.fxh"
#include "shared/cBlendOp.fxh"

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

/*
    [Vertex Shaders]
*/

CShade_VS2PS_Quad VS_Matrix(CShade_APP2VS Input)
{
    // Calculate the shader's HPos and Tex0
    // We modify the Tex0's output afterward
    CShade_VS2PS_Quad Output = CShade_VS_Quad(Input);

    float RotationAngle = radians(_Angle);

    float2x2 RotationMatrix = float2x2
    (
        cos(RotationAngle), -sin(RotationAngle), // Row 1
        sin(RotationAngle), cos(RotationAngle) // Row 2
    );

    float3x3 TranslationMatrix = float3x3
    (
        1.0, 0.0, 0.0, // Row 1
        0.0, 1.0, 0.0, // Row 2
        _Translate.x, _Translate.y, 1.0 // Row 3
    );

    float2x2 ScalingMatrix = float2x2
    (
        _Scale.x, 0.0, // Row 1
        0.0, _Scale.y // Row 2
    );

    // Scale TexCoord from [0,1] to [-1,1]
    Output.Tex0 = Output.Tex0 * 2.0 - 1.0;

    // Do transformations here
    Output.Tex0 = mul(Output.Tex0, RotationMatrix);
    Output.Tex0 = mul(float3(Output.Tex0, 1.0), TranslationMatrix).xy;
    Output.Tex0 = mul(Output.Tex0, ScalingMatrix);

    // Scale TexCoord from [-1,1] to [0,1]
    Output.Tex0 = Output.Tex0 * 0.5 + 0.5;

    return Output;
}

/*
    [Pixel Shaders]
*/

float4 PS_Matrix(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(CShade_SampleColorTex, Input.Tex0).rgb, _CShadeAlphaFactor);
}

technique CShade_Transform
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLENDOP_OUTPUT_CREATE_STATES()

        VertexShader = VS_Matrix;
        PixelShader = PS_Matrix;
    }
}
