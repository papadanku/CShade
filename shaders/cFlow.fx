#define CSHADE_FLOW

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/*
    [Shader Options]
*/

uniform int _DisplayMode <
    ui_category = "Main Shader";
    ui_items = "Shading / Normalized\0Shading / Renormalized\0Line Integral Convolution\0Line Integral Convolution / Colored\0";
    ui_label = "Display Mode";
    ui_type = "combo";
    ui_tooltip = "Selects the visual output mode for optical flow, including normalized or renormalized shading, and different Line Integral Convolution (LIC) visualizations.";
> = 0;

uniform float _MipBias <
    ui_category = "Main Shader";
    ui_label = "Optical Flow Mipmap Level";
    ui_max = 7.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for sampling the optical flow map, affecting the detail and smoothness of the flow vectors.";
> = 0.0;

uniform float _BlendFactor <
    ui_category = "Main Shader";
    ui_label = "Flow Temporal Smoothing";
    ui_max = 0.9;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the temporal smoothing of the optical flow vectors, reducing flickering and making motion appear more fluid over time.";
> = 0.45;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#ifndef SHADER_OPTICAL_FLOW_SAMPLING
    #define SHADER_OPTICAL_FLOW_SAMPLING POINT
#endif

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nSHADER_OPTICAL_FLOW_SAMPLING - How the samples the optical flow map.\n\n\tOptions: LINEAR, POINT\n\n";
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
CREATE_SAMPLER(SampleFlow, TempTex2_RG16F, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)

// This is for LCI.
CREATE_TEXTURE(NoiseTex, BUFFER_SIZE_0, R16, 0)
CREATE_SAMPLER(SampleNoiseTex, NoiseTex, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)

/*
    [Pixel Shaders]
*/

void PS_GenerateNoise(CShade_VS2PS_Quad Input, out float Output : SV_TARGET0)
{
    Output = CMath_GetHash_FLT1(Input.HPos.xy, 0.0);
}

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
    Output = float4(Flow, 0.0, _BlendFactor);
}

/*
    Postfilter median
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

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float2 PixelSize = fwidth(Input.Tex0.xy);
    float2 Vectors = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleFlow, float4(Input.Tex0.xy, 0.0, _MipBias)).xy);

    // Encode vectors
    float3 VectorColors = normalize(float3(Vectors, 1e-3));
    VectorColors.xy = CMath_SNORMtoUNORM_FLT2(VectorColors.xy);
    VectorColors.z = sqrt(1.0 - saturate(dot(VectorColors.xy, VectorColors.xy)));
    VectorColors = normalize(VectorColors);

    // Renormalize motion vectors to take advantage of intensity
    float3 RenormalizedVectorColors = VectorColors / max(max(VectorColors.x, VectorColors.y), VectorColors.z);

    // Line Integral Convolution (LIC)
    float LIC = 0.0;
    float WeightSum = 0.0;

    [unroll]
    for (float i = 1.0; i < 4.0; i += 0.5)
    {
        float2 Offset = Vectors * i;
        LIC += tex2D(SampleNoiseTex, Input.Tex0 + Offset).r;
        LIC += tex2D(SampleNoiseTex, Input.Tex0 - Offset).r;
        WeightSum += 2.0;
    }

    // Normalize LIC
    LIC /= WeightSum;

    // Conditional output
    switch (_DisplayMode)
    {
        case 0:
            Output.rgb = VectorColors;
            break;
        case 1:
            Output.rgb = RenormalizedVectorColors;
            break;
        case 2:
            Output.rgb = LIC;
            break;
        case 3:
            Output.rgb = LIC * RenormalizedVectorColors;
            break;
        default:
            Output.rgb = 0.0;
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

technique GenerateNoise <
    enabled = true;
    timeout = 1;
    hidden = true;
>
{
    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_GenerateNoise;
        RenderTarget0 = NoiseTex;
    }
}

technique CShade_Flow
<
    ui_label = "CShade · Optical Flow";
    ui_tooltip = "Lucas-Kanade optical flow.";
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
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;

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

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
