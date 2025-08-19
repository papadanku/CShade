#define CSHADE_TEXTUREMAD

/*
    [Shader Options]
*/

#include "shared/cMath.fxh"

#ifndef SHADER_BACKBUFFER_ADDRESSU
    #define SHADER_BACKBUFFER_ADDRESSU BORDER
#endif
#ifndef SHADER_BACKBUFFER_ADDRESSV
    #define SHADER_BACKBUFFER_ADDRESSV BORDER
#endif
#ifndef SHADER_BACKBUFFER_ADDRESSW
    #define SHADER_BACKBUFFER_ADDRESSW BORDER
#endif
#ifndef SHADER_BACKBUFFER_SAMPLING
    #define SHADER_BACKBUFFER_SAMPLING POINT
#endif

uniform int _GeometricTransformOrder <
    ui_category = "Geometric Transform";
    ui_label = "Order of Operations";
    ui_type = "combo";
    ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0";
> = 0;

uniform float _Angle <
    ui_category = "Geometric Transform";
    ui_label = "Rotation";
    ui_type = "drag";
> = 0.0;

uniform float2 _Translate <
    ui_category = "Geometric Transform";
    ui_label = "Translation";
    ui_type = "drag";
> = 0.0;

uniform float2 _Scale <
    ui_category = "Geometric Transform";
    ui_label = "Scaling";
    ui_type = "drag";
> = 1.0;

uniform int _ColorOperationsOrder <
    ui_category = "Color Transform";
    ui_label = "Order of Operations";
    ui_type = "combo";
    ui_items = "Multiply > Add\0Add > Multiply\0";
> = 0;

uniform float4 _Multiply <
    ui_category = "Color Transform";
    ui_label = "Multiplication";
    ui_type = "slider";
    ui_min = -2.0;
    ui_max = 2.0;
> = 1.0;

uniform float4 _Addition <
    ui_category = "Color Transform";
    ui_label = "Addition";
    ui_type = "slider";
    ui_min = -2.0;
    ui_max = 2.0;
> = 0.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

uniform bool _BlendWithAlpha <
    ui_category = "Pipeline · Output · Blending";
    ui_label = "Blend With Alpha Channel";
    ui_tooltip = "If the user enabled CBLEND_BLENDENABLE, blend with the computed alpha channel.";
    ui_type = "radio";
> = false;

CREATE_SRGB_SAMPLER(SampleTransformTex, CShade_ColorTex, SHADER_BACKBUFFER_SAMPLING, SHADER_BACKBUFFER_SAMPLING, LINEAR, SHADER_BACKBUFFER_ADDRESSU, SHADER_BACKBUFFER_ADDRESSV, SHADER_BACKBUFFER_ADDRESSW)

/*
    [Vertex Shaders]
*/

CShade_VS2PS_Quad VS_Matrix(CShade_APP2VS Input)
{
    // Calculate the shader's HPos and Tex0
    CShade_VS2PS_Quad Output = CShade_VS_Quad(Input);

    // Apply Geometric Transform
    const float Pi2 = CMath_GetPi() * 2.0;
    CMath_ApplyGeometricTransform(Output.Tex0, _GeometricTransformOrder, _Angle * Pi2, _Translate, _Scale);

    return Output;
}

/*
    [Pixel Shaders]
*/

void ApplyColorTransform(inout float4 Texture)
{
    /*
        The array containing the permutations of the geometric transforms.
        0 = Multiply, 1 = Add
        The index of this array is driven by the _ColorformOrder uniform.
        To get the correct permutation, you would access this array like:
        int2 Order = TransformPermutations[_ColorformOrder];
    */
    int2 TransformPermutations[2] =
    {
        int2(0, 1), // Multiply > Add
        int2(1, 0)  // Add > Multiply
    };

    int2 Order = TransformPermutations[_ColorOperationsOrder];

    // Apply transformations
    [unroll]
    for (int i = 0; i < 2; i++)
    {
        Texture = (Order[i] == 0) ? Texture * _Multiply : Texture;
        Texture = (Order[i] == 1) ? Texture + _Addition : Texture;
    }
}

float4 PS_TextureMAD(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Texture = CShadeHDR_Tex2Dlod_TonemapToRGB(SampleTransformTex, float4(Input.Tex0, 0.0, 0.0));

    // Apply the color transform
    ApplyColorTransform(Texture);

    #if CBLEND_BLENDENABLE
        float Alpha = _BlendWithAlpha ? Texture.a * _CShadeAlphaFactor : _CShadeAlphaFactor;
    #else
        float Alpha = Texture.a;
    #endif

    return CBlend_OutputChannels(float4(Texture.rgb, Alpha));
}

technique CShade_SolidColor
<
    ui_label = "CShade · Geometric & Color Transform";
    ui_tooltip = "Translate, scale, and/or rotate the backbuffer.\n\n* Preprocessor Definitions *\n\nSHADER_BACKBUFFER_ADDRESSU - How the shader renders pixels outside the texture's boundaries (U).\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_BACKBUFFER_ADDRESSV - How the shader renders pixels outside the texture's boundaries (V).\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_BACKBUFFER_ADDRESSW - How the shader renders pixels outside the texture's boundaries (W).\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_BACKBUFFER_SAMPLING - How the shader samples pixels from the backbuffer texture.\n\n\tOptions: POINT, LINEAR";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = VS_Matrix;
        PixelShader = PS_TextureMAD;
    }
}
