#define CSHADE_TRANSFORM

/*
    This shader provides comprehensive geometric and color transformations for an image, allowing users to translate, scale, and rotate the base image. It also supports an overlay system, enabling a separate texture to be transformed and composited onto the base. Both the base layer and the overlay have independent controls for geometric transformations (scale, rotate, translate) and their order of application. Additionally, the shader offers color transformations (multiplication and addition) and an overlay mask for controlled blending.
*/

/*
    Geometric and color transform shader with a single-texture overlay system.
*/

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

uniform bool _BlendWithAlpha <
    ui_label = "Blend with Texture Alpha";
    ui_type = "radio";
    ui_tooltip = "When enabled, the output color will be blended with the computed alpha channel from the texture.";
> = false;

uniform int _RenderMode <
    ui_items = "Base\0Base + Overlay\0";
    ui_label = "Rendering Mode";
    ui_type = "combo";
    ui_tooltip = "Switches between rendering the base layer with transformations or compositing an overlay layer.";
> = 0;

uniform int _BaseGeometricTransformOrder <
    ui_category = "Main Shader / Geometric Transform";
    ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0";
    ui_label = "Transform Order";
    ui_text = "BASE LAYER";
    ui_type = "combo";
    ui_tooltip = "Defines the order in which scaling, rotation, and translation operations are applied to the base layer.";
> = 0;

uniform float _BaseAngle <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Rotation Angle";
    ui_type = "drag";
    ui_tooltip = "Controls the rotation of the base layer around its center.";
> = 0.0;

uniform float2 _BaseTranslate <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Translation";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical translation (position) of the base layer.";
> = 0.0;

uniform float2 _BaseScale <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Scale";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical scaling of the base layer.";
> = 1.0;

uniform int _OverlayTransformOrder <
    ui_category = "Main Shader / Geometric Transform";
    ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0";
    ui_label = "Transform Order";
    ui_text = "OVERLAY LAYER";
    ui_type = "combo";
    ui_tooltip = "Defines the order in which scaling, rotation, and translation operations are applied to the overlay layer.";
> = 0;

uniform float _OverlayAngle <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Rotation Angle";
    ui_type = "drag";
    ui_tooltip = "Controls the rotation of the overlay layer around its center.";
> = 0.0;

uniform float2 _OverlayTranslate <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Translation";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical translation (position) of the overlay layer.";
> = 0.0;

uniform float2 _OverlayScale <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Scale";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical scaling of the overlay layer.";
> = 0.5;

uniform int _OverlayMaskTransformOrder <
    ui_category = "Main Shader / Geometric Transform";
    ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0";
    ui_label = "Transform Order";
    ui_text = "OVERLAY MASK";
    ui_type = "combo";
    ui_tooltip = "Defines the order in which geometric transformations are applied to the overlay mask.";
> = 0;

uniform float _OverlayMaskAngle <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Rotation Angle";
    ui_type = "drag";
    ui_tooltip = "Controls the rotation of the overlay mask around its center.";
> = 0.0;

uniform float2 _OverlayMaskTranslate <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Translation";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical translation (position) of the overlay mask.";
> = 0.0;

uniform float2 _OverlayMaskScale <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Scale";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical scaling of the overlay mask.";
> = 1.0;

uniform float2 _OverlayMaskCutoff <
    ui_category = "Main Shader / Geometric Transform";
    ui_label = "Cutoff Values";
    ui_type = "drag";
    ui_tooltip = "Defines the cutoff values for the overlay mask, determining which parts of the overlay are visible.";
> = 0.5;

uniform int _ColorOperationsOrder <
    ui_category = "Main Shader / Color Transform";
    ui_items = "Multiply > Add\0Add > Multiply\0";
    ui_label = "Transform Order";
    ui_type = "combo";
    ui_tooltip = "Defines the order in which color multiplication and addition operations are applied.";
> = 0;

uniform float4 _Multiply <
    ui_category = "Main Shader / Color Transform";
    ui_label = "Multiplication Factor";
    ui_max = 2.0;
    ui_min = -2.0;
    ui_type = "slider";
    ui_tooltip = "Applies a multiplication factor to the RGB color channels, affecting brightness and saturation.";
> = 1.0;

uniform float4 _Addition <
    ui_category = "Main Shader / Color Transform";
    ui_label = "Addition Factor";
    ui_max = 2.0;
    ui_min = -2.0;
    ui_type = "slider";
    ui_tooltip = "Applies an addition factor to the RGB color channels, shifting the overall brightness.";
> = 0.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nSHADER_BACKBUFFER_ADDRESSU - How the shader renders pixels outside the texture's boundaries (U).\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_BACKBUFFER_ADDRESSV - How the shader renders pixels outside the texture's boundaries (V).\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_BACKBUFFER_ADDRESSW - How the shader renders pixels outside the texture's boundaries (W).\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_BACKBUFFER_SAMPLING - How the shader samples pixels from the backbuffer texture.\n\n\tOptions: POINT, LINEAR\n\n";
    ui_type = "radio";
> = 0;

CSHADE_CREATE_SRGB_SAMPLER(SampleTransformTex, CShade_ColorTex, SHADER_BACKBUFFER_SAMPLING, SHADER_BACKBUFFER_SAMPLING, LINEAR, SHADER_BACKBUFFER_ADDRESSU, SHADER_BACKBUFFER_ADDRESSV, SHADER_BACKBUFFER_ADDRESSW)

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

float CreateOverlayMask(float2 Tex)
{
    float2 Shaper = step(abs(Tex), _OverlayMaskCutoff);
    return Shaper.x * Shaper.y;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    const float Pi2 = CMath_GetPi() * 2.0;

    if (_RenderMode == 1)
    {
        float2 BaseTex = Input.Tex0;
        float2 OverlayTex = Input.Tex0;
        float2 OverlayMaskTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);

        // Apply transformations
        CMath_ApplyGeometricTransform(BaseTex, _BaseGeometricTransformOrder, _BaseAngle * Pi2, _BaseTranslate, _BaseScale, true);
        CMath_ApplyGeometricTransform(OverlayTex, _OverlayTransformOrder, _OverlayAngle * Pi2, _OverlayTranslate, _OverlayScale, true);
        CMath_ApplyGeometricTransform(OverlayMaskTex, _OverlayMaskTransformOrder, _OverlayMaskAngle * Pi2, _OverlayMaskTranslate, _OverlayMaskScale, false);

        // Composite OverlayTex over base tex
        float OverlayMask = CreateOverlayMask(OverlayMaskTex);
        Input.Tex0 = lerp(BaseTex, OverlayTex, OverlayMask);
    }
    else
    {
        CMath_ApplyGeometricTransform(Input.Tex0, _BaseGeometricTransformOrder, _BaseAngle * Pi2, _BaseTranslate, _BaseScale, true);
    }

    // Sample the texture and apply the color transform
    float4 Texture = CShadeHDR_Tex2Dlod_TonemapToRGB(SampleTransformTex, float4(Input.Tex0, 0.0, 0.0));
    ApplyColorTransform(Texture);

    #if (CBLEND_BLENDENABLE == TRUE)
        float Alpha = _CShade_AlphaFactor;
        if (_BlendWithAlpha)
        {
            Alpha *= Texture.a;
        }
    #else
        float Alpha = 1.0;
    #endif

    Output = CBlend_OutputChannels(Texture.rgb, Alpha);
}

technique CShade_SolidColor
<
    ui_label = "CShade / Geometric & Color Transform";
    ui_tooltip = "Translate, scale, and/or rotate the backbuffer.";
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
