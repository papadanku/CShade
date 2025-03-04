#define CSHADE_MOTIONSTABILIZATION

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"
#include "shared/cProcedural.fxh"

/*
    [Shader Options]
*/

#ifndef STABILIZATION_POINT_SAMPLING
    #define STABILIZATION_POINT_SAMPLING 1
#endif

#ifndef STABILIZATION_ADDRESS
    #define STABILIZATION_ADDRESS BORDER
#endif

#if STABILIZATION_POINT_SAMPLING
    #define STABILIZATION_FILTER POINT
#else
    #define STABILIZATION_FILTER LINEAR
#endif

uniform float _FrameTime < source = "frametime"; > ;

uniform float _BlendFactor <
    ui_category = "Shader | Stabilization";
    ui_label = "Temporal Blending Strength";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float _Stabilization <
    ui_category = "Shader | Stabilization";
    ui_label = "Stabilization Strengh";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 16.0;
> = 8.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex1_RG8, BUFFER_SIZE_1, RG8, 8)
CREATE_TEXTURE_POOLED(TempTex2_RG16F, BUFFER_SIZE_3, RG16F, 8)
CREATE_TEXTURE_POOLED(TempTex3_RG16F, BUFFER_SIZE_4, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RG16F, BUFFER_SIZE_5, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RG16F, BUFFER_SIZE_6, RG16F, 1)

CREATE_SAMPLER(SampleTempTex1, TempTex1_RG8, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex2, TempTex2_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_TEXTURE(Tex2c, BUFFER_SIZE_3, RG8, 8)
CREATE_SAMPLER(SampleTex2c, Tex2c, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_TEXTURE(OFlowTex, BUFFER_SIZE_3, RG16F, 1)
CREATE_SAMPLER(SampleOFlowTex, OFlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_SRGB_SAMPLER(SampleStableTex, CShade_ColorTex, STABILIZATION_FILTER, STABILIZATION_FILTER, STABILIZATION_FILTER, STABILIZATION_ADDRESS, STABILIZATION_ADDRESS, STABILIZATION_ADDRESS)

/*
    [Pixel Shaders]
*/

float2 PS_Normalize(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb;
    return CColor_GetSphericalRG(Color).xy;
}

// Run Lucas-Kanade

float2 PS_LucasKanade4(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = 0.0;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float2 PS_LucasKanade3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetDilatedPyramidUpsample(SampleTempTex5, Input.Tex0).xy;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float2 PS_LucasKanade2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetDilatedPyramidUpsample(SampleTempTex4, Input.Tex0).xy;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float4 PS_LucasKanade1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetDilatedPyramidUpsample(SampleTempTex3, Input.Tex0).xy;
    float2 Flow = CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
    return float4(Flow, 0.0, saturate(0.9 * lerp(1.0, 1.1, _BlendFactor)));
}

/*
    Post-process filtering
*/

float4 PS_Copy(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(SampleTempTex1, Input.Tex0.xy).rg, 0.0, 1.0);
}

float4 PS_Median(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_FilterMotionVectors(SampleOFlowTex, Input.Tex0, 0.0, true).rg, 0.0, 1.0);
}

float4 PS_Upsample(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_UpsampleMotionVectors(SampleTempTex5, SampleOFlowTex, Input.Tex0, 2.5).rg, 0.0, 1.0);
}

float4 PS_MotionStabilization(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 PixelSize = fwidth(Input.Tex0.xy);
    float2 MotionVectors = CMath_Float2_FP16ToNorm(tex2Dlod(SampleTempTex2, float4(0.5, 0.0, 0.0, 99.0)).xy);

    float2 StableTex = Input.Tex0.xy - 0.5;
    StableTex -= (MotionVectors * _Stabilization);
    StableTex += 0.5;

    float4 Color = CShadeHDR_Tex2D_InvTonemap(SampleStableTex, StableTex);

    return CBlend_OutputChannels(float4(Color.rgb, _CShadeAlphaFactor));
}

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_MotionStabilization < ui_tooltip = "Motion stabilization effect.\n\nStabilization Address Options:\n\n- CLAMP\n- MIRROR\n- WRAP or REPEAT\n- BORDER"; >
{
    // Normalize current frame
    CREATE_PASS(CShade_VS_Quad, PS_Normalize, TempTex1_RG8)

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
        RenderTarget0 = OFlowTex;
    }

    pass Copy
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = Tex2c;
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
        PixelShader = PS_Upsample;
        RenderTarget0 = TempTex2_RG16F;
    }

    pass MotionStabilization
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_MotionStabilization;
    }
}
