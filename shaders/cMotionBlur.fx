#define CSHADE_MOTIONBLUR

/*
    This shader applies a motion blur effect to the image by utilizing optical flow information calculated through the Lucas-Kanade method. It detects movement between frames and blurs pixels along their motion paths, creating a sense of speed or dynamic action. The shader provides controls for temporal smoothing of motion vectors, frame rate scaling for blur intensity, and options for unidirectional or bidirectional blurring. It also includes debug display modes to visualize motion vectors.
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/* Shader Options */

uniform float _FrameTime < source = "frametime"; > ;

uniform int _DisplayMode <
    ui_category = "Main Shader";
    ui_items = "Output\0Debug · Quadrant\0Debug · Motion Vector Direction\0Debug · Motion Vector Magnitude\0";
    ui_label = "Display Mode";
    ui_text = "OPTICAL FLOW";
    ui_type = "combo";
    ui_tooltip = "Controls how the optical flow information is displayed, including different debug views.";
> = 0;

uniform float _MipBias <
    ui_category = "Main Shader";
    ui_label = "Optical Flow Mipmap Level";
    ui_max = 7.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for texture sampling, which affects the level of detail.";
> = 0.0;

uniform float _BlendFactor <
    ui_category = "Main Shader";
    ui_label = "Motion Blur Temporal Smoothing";
    ui_max = 0.9;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the amount of temporal smoothing applied to the motion vectors, reducing flickering.";
> = 0.25;

uniform bool _FrameRateScaling <
    ui_category = "Main Shader";
    ui_label = "Scale Blur with Frame Rate";
    ui_text = "MOTION BLUR";
    ui_type = "radio";
    ui_tooltip = "When enabled, the motion blur effect will adjust its intensity based on the current frame rate.";
> = false;

uniform int _BlurAccumuation <
    ui_category = "Main Shader";
    ui_items = "Average\0Max\0";
    ui_label = "Blur Combination Method";
    ui_type = "combo";
    ui_tooltip = "Selects how individual blur samples are combined: either by averaging them or taking the maximum value.";
> = 0;

uniform int _BlurDirection <
    ui_category = "Main Shader";
    ui_items = "Unidirectional\0Bidirectional\0";
    ui_label = "Motion Blur Direction";
    ui_type = "combo";
    ui_tooltip = "Determines if the motion blur extends in one direction (unidirectional) or both directions (bidirectional) from the original position.";
> = 0;

uniform float _Scale <
    ui_category = "Main Shader";
    ui_label = "Motion Blur Intensity";
    ui_max = 4.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the overall intensity or length of the motion blur effect.";
> = 1.0;

uniform float _TargetFrameRate <
    ui_category = "Main Shader";
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

CSHADE_CREATE_TEXTURE_POOLED(TempTex1_RGB10A2, CSHADE_BUFFER_SIZE_1, RGB10A2, 8)
CSHADE_CREATE_TEXTURE_POOLED(TempTex2_RG16F, CSHADE_BUFFER_SIZE_3, RG16F, 8)
CSHADE_CREATE_TEXTURE_POOLED(TempTex3_RG16F, CSHADE_BUFFER_SIZE_4, RG16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(TempTex4_RG16F, CSHADE_BUFFER_SIZE_5, RG16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(TempTex5_RG16F, CSHADE_BUFFER_SIZE_6, RG16F, 1)

CSHADE_CREATE_SAMPLER(SampleTempTex1, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex2, TempTex2_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CSHADE_CREATE_TEXTURE(PreviousFrameTex, CSHADE_BUFFER_SIZE_1, RGB10A2, 8)
CSHADE_CREATE_SAMPLER_LODBIAS(SamplePreviousFrameTex, PreviousFrameTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CSHADE_CREATE_SAMPLER_LODBIAS(SampleCurrentFrameTex, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

CSHADE_CREATE_TEXTURE(FlowTex, CSHADE_BUFFER_SIZE_3, RG16F, 8)
CSHADE_CREATE_SAMPLER_LODBIAS(SampleGuide, FlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

/* Pixel Shaders */

void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
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
    Output = float4(Flow, 0.0, _BlendFactor);
}

/*
    Postfilter median
*/

// We use MRT to immeduately copy the current blurred frame for the next frame
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
        float4 Color = tex2D(CShade_SampleColorTex, LocalTex);
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

    float4 Base = tex2D(CShade_SampleColorTex, Input.Tex0);
    float2 MotionVectors = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleTempTex2, float4(Input.Tex0.xy, 0.0, _MipBias)).xy);
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
    CShade_Render(Output, Input.HPos, Input.Tex0);
}

#define CREATE_PASS(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass NAME \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_MotionBlur
<
    ui_label = "CShade | Motion Blur";
    ui_tooltip = "Motion blur effect.";
>
{
    CREATE_PASS(Pyramid, CShade_VS_Quad, PS_Pyramid, TempTex1_RGB10A2)

    CREATE_PASS(LucasKanade4, CShade_VS_Quad, PS_LucasKanade4, TempTex5_RG16F)
    CREATE_PASS(LucasKanade3, CShade_VS_Quad, PS_LucasKanade3, TempTex4_RG16F)
    CREATE_PASS(LucasKanade2, CShade_VS_Quad, PS_LucasKanade2, TempTex3_RG16F)
    pass GetFineOpticalFlow
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_LucasKanade1;
        RenderTarget0 = FlowTex;
    }

    pass CopyFrame
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

    pass BilateralUpsample1
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample1;
        RenderTarget0 = TempTex4_RG16F;
    }

    pass BilateralUpsample2
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample2;
        RenderTarget0 = TempTex3_RG16F;
    }

    pass BilateralUpsample3
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample3;
        RenderTarget0 = TempTex2_RG16F;
    }

    pass MotionBlur
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
