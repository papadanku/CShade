#define CSHADE_MOTIONBLUR

/*
    This shader applies a motion blur effect to the image by utilizing optical flow information calculated through the Lucas-Kanade method. It detects movement between frames and blurs pixels along their motion paths, creating a sense of speed or dynamic action. The shader provides controls for temporal smoothing of motion vectors, frame rate scaling for blur intensity, and options for unidirectional or bidirectional blurring. It also includes debug display modes to visualize motion vectors.
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/* Shader Options */

#ifndef SHADER_USE_CSHARES_MOTION_VECTORS
    #define SHADER_USE_CSHARES_MOTION_VECTORS 0
#endif

uniform float _FrameTime <
    source = "frametime";
    ui_tooltip = "The time elapsed since the last frame, used for time-based effects.";
>;

uniform int _DisplayMode <
    ui_items = "Output\0Debug · Quadrant\0Debug · Motion Vector Direction\0Debug · Motion Vector Magnitude\0";
    ui_label = "Display Mode";
    ui_text = "OPTICAL FLOW";
    ui_type = "combo";
    ui_tooltip = "Controls how the optical flow information is displayed, including different debug views.";
> = 0;

uniform bool _FrameRateScaling <
    ui_label = "Scale Blur with Frame Rate";
    ui_text = "MOTION BLUR";
    ui_type = "radio";
    ui_tooltip = "When enabled, the motion blur effect will adjust its intensity based on the current frame rate.";
> = false;

uniform int _BlurAccumuation <
    ui_items = "Average\0Max\0";
    ui_label = "Blur Combination Method";
    ui_type = "combo";
    ui_tooltip = "Selects how individual blur samples are combined: either by averaging them or taking the maximum value.";
> = 0;

uniform int _BlurDirection <
    ui_items = "Unidirectional\0Bidirectional\0";
    ui_label = "Motion Blur Direction";
    ui_type = "combo";
    ui_tooltip = "Determines if the motion blur extends in one direction (unidirectional) or both directions (bidirectional) from the original position.";
> = 0;

uniform float _Scale <
    ui_label = "Motion Blur Intensity";
    ui_max = 4.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the overall intensity or length of the motion blur effect.";
> = 1.0;

uniform float _TargetFrameRate <
    ui_label = "Target Frame Rate for Scaling";
    ui_max = 144.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Sets the target frame rate used for scaling the motion blur effect, especially when 'Enable Frame Rate Scaling' is active.";
> = 60.0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/* Textures & Samplers */

#if SHADER_USE_CSHARES_MOTION_VECTORS
    CSHADE_CREATE_TEXTURE(CShade_Mainframe_MotionVectors, CSHADE_BUFFER_SIZE_2, RG16F, 1)

    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex, CShade_Mainframe_MotionVectors, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
#else
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_1, CSHADE_BUFFER_SIZE_1, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)

    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_2_A, CSHADE_BUFFER_SIZE_2, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_A, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_A, CSHADE_BUFFER_SIZE_4, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_5_A, CSHADE_BUFFER_SIZE_5, RG16F, 1)

    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_2_B, CSHADE_BUFFER_SIZE_2, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_B, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_B, CSHADE_BUFFER_SIZE_4, RG16F, 1)

    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowBlur_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowBlur_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowBlur_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowBlur_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_1, SharedTex_RGB10A2_1, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_2, SharedTex_RGB10A2_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_3, SharedTex_RGB10A2_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_4, SharedTex_RGB10A2_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_5, SharedTex_RGB10A2_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_2_A, SharedTex_RG16F_2_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_3_A, SharedTex_RG16F_3_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_4_A, SharedTex_RG16F_4_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_5_A, SharedTex_RG16F_5_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_2_B, SharedTex_RG16F_2_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_3_B, SharedTex_RG16F_3_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_4_B, SharedTex_RG16F_4_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowBlur_2, PreviousFrameTex_FlowBlur_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowBlur_3, PreviousFrameTex_FlowBlur_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowBlur_4, PreviousFrameTex_FlowBlur_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowBlur_5, PreviousFrameTex_FlowBlur_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

#if !SHADER_USE_CSHARES_MOTION_VECTORS

    /* Pixel Shaders: Pyramid */

    void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float4 Color = tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(Input.Tex0));
        Output.rgb = sqrt(Color.rgb);
        Output.a = 1.0;
    }

    void PS_PyramidLevel1(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_1, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    void PS_PyramidLevel2(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_2, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    void PS_PyramidLevel3(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_3, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    void PS_PyramidLevel4(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_4, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    /* Pixel Shaders: Lucas-Kanade */

    void PS_LucasKanade4(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 Vectors = 0.0;
        float2 PixelSize = fwidth(Input.Tex0.xy);
        Output = CMotionEstimation_GetLucasKanade(true, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowBlur_5, SampleSharedTex_RGB10A2_5);
    }

    void PS_LucasKanade3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_5_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowBlur_4, SampleSharedTex_RGB10A2_4);
    }

    void PS_LucasKanade2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_4_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowBlur_3, SampleSharedTex_RGB10A2_3);
    }

    void PS_LucasKanade1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_3_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowBlur_2, SampleSharedTex_RGB10A2_2);
    }

    /* Pixel Shaders: Downsample */

    void PS_Downsample1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_2_A, Input.Tex0, PixelSize).xy;
    }

    void PS_Downsample2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_3_A, Input.Tex0, PixelSize).xy;
    }

    void PS_Downsample3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_4_A, Input.Tex0, PixelSize).xy;
    }

    /* Pixel Shaders: Upsample & Blit */

    void PS_CopyCoarse(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        Output = tex2Dlod(SampleSharedTex_RGB10A2_5, CShade_PadFloat2(Input.Tex0));
    }

    void PS_Upsample3_Copy3(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
    {
        Output0 = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_5_A, SampleSharedTex_RG16F_4_A, Input.Tex0);
        Output1 = tex2Dlod(SampleSharedTex_RGB10A2_4, CShade_PadFloat2(Input.Tex0));
    }

    void PS_Upsample2_Copy2(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
    {
        Output0 = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_4_B, SampleSharedTex_RG16F_3_A, Input.Tex0);
        Output1 = tex2Dlod(SampleSharedTex_RGB10A2_3, CShade_PadFloat2(Input.Tex0));
    }

    void PS_Upsample1_Copy1(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
    {
        Output0 = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_3_B, SampleSharedTex_RG16F_2_A, Input.Tex0);
        Output1 = tex2Dlod(SampleSharedTex_RGB10A2_2, CShade_PadFloat2(Input.Tex0));
    }

#endif

float3 GetMotionBlur(CShade_VS2PS_Quad Input, float2 MotionVectors)
{
    const int Samples = 8;
    float4 OutputColor = 0.0;

    float FrameRate = 1e+3 / _FrameTime;
    float FrameTimeRatio = _TargetFrameRate / FrameRate;
    float Noise = CMath_GetGoldenRatioNoise(Input.HPos.xy);

    float2 ScaledMotionVectors = MotionVectors * _Scale;
    ScaledMotionVectors = (_FrameRateScaling) ? ScaledMotionVectors / FrameTimeRatio : ScaledMotionVectors;

    [unroll]
    for (int i = 0; i < Samples; ++i)
    {
        float Random = (_BlurDirection == 1) ? CMath_UNORMtoSNORM_FLT1(Noise) : Noise;
        float MotionMultiplier = (float(i) + Random) / float(Samples - 1);
        float2 LocalTex = Input.Tex0 - (ScaledMotionVectors * MotionMultiplier);
        float4 Color = tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(LocalTex));
        if (_BlurAccumuation == 1)
        {
            OutputColor = max(Color, OutputColor);
        }
        else
        {
            OutputColor += (Color / Samples);
        }
    }

    return OutputColor.rgb;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    CMath_TexGrid Grid = CMath_GetTexGrid(Input.Tex0, 2);

    if (_DisplayMode == 1)
    {
        Input.Tex0 = Grid.Frac;
    }

    float4 Base = tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(Input.Tex0));
    float4 MotionVectorsTex = CShade_PadFloat2(Input.Tex0.xy);
    float2 MotionVectors = CMath_FP16toSNORM_FLT2(tex2Dlod(SampleSharedTex_RG16F_2_B, MotionVectorsTex).xy);
    float3 ShaderOutput = GetMotionBlur(Input, MotionVectors);

    switch (_DisplayMode)
    {
        case 0:
            Output.rgb = ShaderOutput.rgb;
            break;
        case 1:
            Output.rgb = CMotionEstimation_GetDebugQuadrant(Base.rgb, ShaderOutput, MotionVectors, Grid.Index);
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

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Output.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Output.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

#define TEMPLATE_PASS(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass NAME \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

#define TEMPLATE_PASS_MRT2(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET_0, RENDER_TARGET_1) \
    pass NAME \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET_0; \
        RenderTarget1 = RENDER_TARGET_1; \
    }

#if SHADER_USE_CSHARES_MOTION_VECTORS
    #define SHADER_UI_LABEL_EXT " & CShares"
#else
    #define SHADER_UI_LABEL_EXT ""
#endif

#define SHADER_UI_LABEL "CShade" SHADER_UI_LABEL_EXT " | Motion Blur"

technique CShade_MotionBlur
<
    ui_label = SHADER_UI_LABEL;
    ui_tooltip = "Motion blur effect.";
>
{
    #if !SHADER_USE_CSHARES_MOTION_VECTORS
        // Prepare
        TEMPLATE_PASS(Pyramid, CShade_VS_Quad, PS_Pyramid, SharedTex_RGB10A2_1)

        // Construct Pyramid 1
        TEMPLATE_PASS(Pyramid1, CShade_VS_Quad, PS_PyramidLevel1, SharedTex_RGB10A2_2)
        TEMPLATE_PASS(Pyramid2, CShade_VS_Quad, PS_PyramidLevel2, SharedTex_RGB10A2_3)
        TEMPLATE_PASS(Pyramid3, CShade_VS_Quad, PS_PyramidLevel3, SharedTex_RGB10A2_4)
        TEMPLATE_PASS(Pyramid4, CShade_VS_Quad, PS_PyramidLevel4, SharedTex_RGB10A2_5)

        // Process Lucas-Kanade
        TEMPLATE_PASS(LucasKanade4, CShade_VS_Quad, PS_LucasKanade4, SharedTex_RG16F_5_A)
        TEMPLATE_PASS(LucasKanade3, CShade_VS_Quad, PS_LucasKanade3, SharedTex_RG16F_4_A)
        TEMPLATE_PASS(LucasKanade2, CShade_VS_Quad, PS_LucasKanade2, SharedTex_RG16F_3_A)
        TEMPLATE_PASS(LucasKanade1, CShade_VS_Quad, PS_LucasKanade1, SharedTex_RG16F_2_A)

        // Build Pyramid 2
        TEMPLATE_PASS(Downsample1, CShade_VS_Quad, PS_Downsample1, SharedTex_RG16F_3_A)
        TEMPLATE_PASS(Downsample2, CShade_VS_Quad, PS_Downsample2, SharedTex_RG16F_4_A)
        TEMPLATE_PASS(Downsample3, CShade_VS_Quad, PS_Downsample3, SharedTex_RG16F_5_A)

        // Apply Filtering
        TEMPLATE_PASS(CopyCoarse, CShade_VS_Quad, PS_CopyCoarse, PreviousFrameTex_FlowBlur_5)
        TEMPLATE_PASS_MRT2(Upsample3_Copy3, CShade_VS_Quad, PS_Upsample3_Copy3, SharedTex_RG16F_4_B, PreviousFrameTex_FlowBlur_4)
        TEMPLATE_PASS_MRT2(Upsample2_Copy2, CShade_VS_Quad, PS_Upsample2_Copy2, SharedTex_RG16F_3_B, PreviousFrameTex_FlowBlur_3)
        TEMPLATE_PASS_MRT2(Upsample1_Copy1, CShade_VS_Quad, PS_Upsample1_Copy1, SharedTex_RG16F_2_B, PreviousFrameTex_FlowBlur_2)
    #endif

    pass MotionBlur
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
