#define CSHADE_MOTIONSTABILIZATION

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/*
    [Shader Options]
*/

#ifndef SHADER_BACKBUFFER_ADDRESS
    #define SHADER_BACKBUFFER_ADDRESS BORDER
#endif

#ifndef SHADER_DISPLACEMENT_SAMPLING
    #define SHADER_DISPLACEMENT_SAMPLING POINT
#endif

#ifndef SHADER_MOTION_VECTORS_SAMPLING
    #define SHADER_MOTION_VECTORS_SAMPLING LINEAR
#endif

#ifndef SHADER_COSMETIC_SAMPLING
    #define SHADER_COSMETIC_SAMPLING LINEAR
#endif

uniform float _FrameTime < source = "frametime"; > ;

uniform int _DisplayMode <
    ui_items = "Output\0Debug · Quadrant\0Debug · Motion Vector Direction\0Debug · Motion Vector Magnitude\0";
    ui_label = "Display Mode";
    ui_type = "combo";
    ui_tooltip = "Controls how the optical flow information is displayed, including different debug views.";
> = 0;

uniform bool _InvertWarpX <
    ui_category = "Main Shader";
    ui_label = "Invert Horizontal Stabilization";
    ui_text = "Motion Stabilization";
    ui_type = "radio";
    ui_tooltip = "Inverts the motion stabilization effect along the horizontal (X) axis.";
> = false;

uniform bool _InvertWarpY <
    ui_category = "Main Shader";
    ui_label = "Invert Vertical Stabilization";
    ui_type = "radio";
    ui_tooltip = "Inverts the motion stabilization effect along the vertical (Y) axis.";
> = false;

uniform bool _GlobalStabilization <
    ui_category = "Main Shader";
    ui_label = "Use Global Stabilization";
    ui_type = "radio";
    ui_tooltip = "When enabled, the entire frame is stabilized based on overall motion, rather than local movements.";
> = false;

uniform float _LocalStabilizationMipBias <
    ui_category = "Main Shader";
    ui_label = "Local Stabilization Mipmap Level";
    ui_max = 7.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for local stabilization, which affects the level of detail considered for motion.";
> = 3.5;

uniform float2 _WarpStrength <
    ui_category = "Main Shader";
    ui_label = "Stabilization Warp Strength";
    ui_max = 8.0;
    ui_min = -8.0;
    ui_type = "slider";
    ui_tooltip = "Controls the intensity of the image warping applied for motion stabilization.";
> = 1.0;

uniform float _BlendFactor <
    ui_category = "Main Shader";
    ui_label = "Stabilization Temporal Smoothing";
    ui_max = 8.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the amount of temporal smoothing applied to the motion vectors, reducing flickering.";
> = 1.0;

uniform int _GeometricTransformOrder <
    ui_category = "Main Shader";
    ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0";
    ui_label = "Geometric Transform Order";
    ui_text = "\nGeometric Transform";
    ui_type = "combo";
    ui_tooltip = "Defines the order in which scaling, rotation, and translation operations are applied to the image.";
> = 0;

uniform float _Angle <
    ui_category = "Main Shader";
    ui_label = "Geometric Rotation";
    ui_type = "drag";
    ui_tooltip = "Controls the rotation of the image around its center.";
> = 0.0;

uniform float2 _Translate <
    ui_category = "Main Shader";
    ui_label = "Geometric Translation";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical translation (position) of the image.";
> = 0.0;

uniform float2 _Scale <
    ui_category = "Main Shader";
    ui_label = "Geometric Scale";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical scaling of the image.";
> = 1.0;

uniform int _ScaleByImage <
    ui_category = "Main Shader";
    ui_items = "Radial (Luma)\0Polar Angle (Chroma 1)\0Azimuthal Angle (Chroma 2)\0Disabled\0";
    ui_label = "Cosmetic Scaling Method";
    ui_text = "\n[Cosmetic] Image-Based Scaling";
    ui_type = "combo";
    ui_tooltip = "Selects a color channel from the image to use as a scalar for cosmetic scaling effects.";
> = 3;

uniform float _ScaleByImageLOD <
    ui_category = "Main Shader";
    ui_label = "Cosmetic Scaling Mipmap Level";
    ui_type = "drag";
    ui_tooltip = "Adjusts the mipmap level used for the image that influences cosmetic scaling.";
> = 0.5;

uniform float _ScaleByImageIntensity <
    ui_category = "Main Shader";
    ui_label = "Cosmetic Scaling Intensity";
    ui_max = 8.0;
    ui_min = -8.0;
    ui_type = "drag";
    ui_tooltip = "Controls the intensity of the cosmetic scaling effect driven by image content.";
> = 1.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nSHADER_BACKBUFFER_ADDRESS - How the shader renders pixels outside the texture's boundaries.\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_MOTION_VECTORS_SAMPLING - How the shader filters the motion vectors used for stabilization.\n\n\tOptions: LINEAR, POINT\n\nSHADER_DISPLACEMENT_SAMPLING - How the shader filters warped pixels.\n\n\tOptions: LINEAR, POINT\n\nSHADER_COSMETIC_SAMPLING - How the shader filters the image content texture used for color-based displacement.\n\n\tOptions: LINEAR, POINT\n\n";
    ui_type = "radio";
> = 0;

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex1_RGB10A2, BUFFER_SIZE_1, RGB10A2, 8)
CREATE_TEXTURE_POOLED(TempTex2_RG16F, BUFFER_SIZE_3, RG16F, 8)
CREATE_TEXTURE_POOLED(TempTex3_RG16F, BUFFER_SIZE_4, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RG16F, BUFFER_SIZE_5, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RG16F, BUFFER_SIZE_6, RG16F, 1)

CREATE_SAMPLER(SampleTempTex1, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex2, TempTex2_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_TEXTURE(PreviousFrameTex, BUFFER_SIZE_1, RGB10A2, 8)
CREATE_SAMPLER_LODBIAS(SamplePreviousFrameTex, PreviousFrameTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CREATE_SAMPLER_LODBIAS(SampleCurrentFrameTex, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

CREATE_TEXTURE(FlowTex, BUFFER_SIZE_3, RG16F, 8)
CREATE_SAMPLER_LODBIAS(SampleGuide, FlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

CREATE_SAMPLER(SampleStabilizationTex, TempTex2_RG16F, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleStableTex, CShade_ColorTex, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, SHADER_BACKBUFFER_ADDRESS, SHADER_BACKBUFFER_ADDRESS, SHADER_BACKBUFFER_ADDRESS)

CREATE_SAMPLER(SampleCosmeticTex, TempTex1_RGB10A2, SHADER_COSMETIC_SAMPLING, SHADER_COSMETIC_SAMPLING, SHADER_COSMETIC_SAMPLING, SHADER_BACKBUFFER_ADDRESS, SHADER_BACKBUFFER_ADDRESS, SHADER_BACKBUFFER_ADDRESS)

/*
    [Pixel Shaders]
*/

void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0);
    float3 LogColor = CColor_EncodeLogC(Color.rgb) / CColor_EncodeLogC(1.0);

    float Sum = dot(LogColor, 1.0);
    float3 Ratio = abs(Sum) > 0.0 ? LogColor / Sum : 1.0 / 3.0;
    float MaxRatio = max(Ratio.r, max(Ratio.g, Ratio.b));
    float MaxColor = max(LogColor.r, max(LogColor.g, LogColor.b));

    Output.xy = MaxRatio > 0.0 ? Ratio.xy / MaxRatio : 1.0;
    Output.z = MaxColor;
    Output.w = 1.0;
}

// Run Lucas-Kanade

void PS_LucasKanade4(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    float2 Vectors = 0.0;
    Output = CMotionEstimation_GetLucasKanade(true, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

void PS_LucasKanade3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex5).xy;
    Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

void PS_LucasKanade2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex4).xy;
    Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

void PS_LucasKanade1(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex3).xy;
    float2 Flow = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
    Output = float4(Flow, 0.0, 1.0 / (_BlendFactor + 1.0));
}

/*
    Post-process filtering
*/

void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(SampleTempTex1, Input.Tex0.xy);
}

void PS_Median(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetMedian(SampleGuide, Input.Tex0).xy;
}

void PS_Upsample1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSelfBilateralUpsampleXY(SampleTempTex5, SampleGuide, Input.Tex0).xy;
}

void PS_Upsample2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSelfBilateralUpsampleXY(SampleTempTex4, SampleGuide, Input.Tex0).xy;
}

void PS_Upsample3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSelfBilateralUpsampleXY(SampleTempTex3, SampleGuide, Input.Tex0).xy;
}

float4 GetMotionStabilization(CShade_VS2PS_Quad Input, float2 MotionVectors)
{
    MotionVectors.x = _InvertWarpX ? -MotionVectors.x : MotionVectors.x;
    MotionVectors.y = _InvertWarpY ? -MotionVectors.y : MotionVectors.y;

    float2 StableTex = Input.Tex0.xy - 0.5;
    StableTex -= (MotionVectors * _WarpStrength);
    StableTex += 0.5;

    // Apply Geometric Transform
    const float Pi2 = CMath_GetPi() * 2.0;
    CMath_ApplyGeometricTransform(StableTex, _GeometricTransformOrder, _Angle * Pi2, _Translate, _Scale, true);

    return CShadeHDR_GetBackBuffer(SampleStableTex, StableTex);
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    CMath_TexGrid Grid = CMath_GetTexGrid(Input.Tex0, 2);

    if (_DisplayMode == 1)
    {
        Input.Tex0 = Grid.Frac;
    }

    // Get needed LOD for shader
    float2 StabilizationTex = _GlobalStabilization ? 0.5 : Input.Tex0;
    float StabilizationLOD = _GlobalStabilization ? 99.0 : _LocalStabilizationMipBias;

    float4 Base = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0);
    float4 Image = tex2Dlod(SampleCosmeticTex, float4(Input.Tex0, 0.0, _ScaleByImageLOD));
    float2 MotionVectors = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleStabilizationTex, float4(StabilizationTex, 0.0, StabilizationLOD)).xy);
    float4 ShaderOutput = GetMotionStabilization(Input, MotionVectors * Image[_ScaleByImage] * _ScaleByImageIntensity);

    switch (_DisplayMode)
    {
        case 0:
            Output.rgb = ShaderOutput.rgb;
            break;
        case 1:
            Output.rgb = CMotionEstimation_GetDebugQuadrant(Base.rgb, ShaderOutput.rgb, MotionVectors, Grid.Index);
            break;
        case 2:
            Output.rgb = CMotionEstimation_GetMotionVectorRGB(MotionVectors);
            break;
        case 3:
            Output.rgb = length(MotionVectors);
            break;
        default:
            Output.rgb = Base.rgb;
            break;
    }

    Output = CBlend_OutputChannels(Output.rgb, _CShade_AlphaFactor);
}

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_MotionStabilization
<
    ui_label = "CShade / Motion Stabilization";
    ui_tooltip = "Motion stabilization effect.";
>
{
    // Normalize current frame
    CREATE_PASS(CShade_VS_Quad, PS_Pyramid, TempTex1_RGB10A2)

    // Bilinear Lucas-Kanade Optical Flow
    CREATE_PASS(CShade_VS_Quad, PS_LucasKanade4, TempTex5_RG16F)
    CREATE_PASS(CShade_VS_Quad, PS_LucasKanade3, TempTex4_RG16F)
    CREATE_PASS(CShade_VS_Quad, PS_LucasKanade2, TempTex3_RG16F)
    pass GetFineOpticalFlow
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = ONE;
        DestBlend = INVSRCALPHA;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_LucasKanade1;
        RenderTarget0 = FlowTex;
    }

    pass Copy
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = PreviousFrameTex;
    }

    pass Median
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Median;
        RenderTarget0 = TempTex5_RG16F;
    }

    pass BilateralUpsample
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample1;
        RenderTarget0 = TempTex4_RG16F;
    }

    pass BilateralUpsample
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample2;
        RenderTarget0 = TempTex3_RG16F;
    }

    pass BilateralUpsample
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample3;
        RenderTarget0 = TempTex2_RG16F;
    }

    pass MotionStabilization
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
