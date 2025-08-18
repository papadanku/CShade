#define CSHADE_MOTIONSTABILIZATION

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"
#include "shared/cProcedural.fxh"

/*
    [Shader Options]
*/

// Available options: CLAMP, MIRROR, WRAP/REPEAT, BORDER
#ifndef STABILIZATION_ADDRESS
    #define STABILIZATION_ADDRESS BORDER
#endif

// Available options: POINT, LINEAR
#ifndef STABILIZATION_GRID_SAMPLING
    #define STABILIZATION_GRID_SAMPLING LINEAR
#endif

// Available options: POINT, LINEAR
#ifndef STABILIZATION_WARP_SAMPLING
    #define STABILIZATION_WARP_SAMPLING POINT
#endif

uniform float _FrameTime < source = "frametime"; > ;

uniform float _LocalStabilizationMipBias <
    ui_label = "Mipmap Bias";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
> = 3.5;

uniform float2 _WarpStrength <
    ui_label = "Warping Strength";
    ui_type = "slider";
    ui_min = -100.0;
    ui_max = 100.0;
> = 10.0;

uniform float _BlendFactor <
    ui_label = "Temporal Blending Weight";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform bool _InvertWarpX <
    ui_label = "Invert X Axis";
    ui_type = "radio";
> = false;

uniform bool _InvertWarpY <
    ui_label = "Invert Y Axis";
    ui_type = "radio";
> = false;

uniform bool _GlobalStabilization <
    ui_label = "Enable Global Stabilization";
    ui_type = "radio";
> = false;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

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

CREATE_TEXTURE(Tex2c, BUFFER_SIZE_3, RGB10A2, 8)
CREATE_SAMPLER(SampleTex2c, Tex2c, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_SAMPLER(SampleStabilizationTex, TempTex2_RG16F, STABILIZATION_GRID_SAMPLING, STABILIZATION_GRID_SAMPLING, STABILIZATION_GRID_SAMPLING, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleStableTex, CShade_ColorTex, STABILIZATION_WARP_SAMPLING, STABILIZATION_WARP_SAMPLING, STABILIZATION_WARP_SAMPLING, STABILIZATION_ADDRESS, STABILIZATION_ADDRESS, STABILIZATION_ADDRESS)

CREATE_TEXTURE(FlowTex, BUFFER_SIZE_3, RG16F, 8)
CREATE_SAMPLER(SampleGuide, FlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
*/

float4 PS_Pyramid(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = CColor_RGBtoSRGB(CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0)).rgb;
    return float4(CColor_RGBtoSphericalRGB(Color), 1.0);
}

// Run Lucas-Kanade

float2 PS_LucasKanade4(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = 0.0;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float2 PS_LucasKanade3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex5).xy;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float2 PS_LucasKanade2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex4).xy;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float4 PS_LucasKanade1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex3).xy;
    float2 Flow = CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
    return float4(Flow, 0.0, saturate(0.9 * lerp(1.0, 1.1, _BlendFactor)));
}

/*
    Post-process filtering
*/

float4 PS_Copy(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(SampleTempTex1, Input.Tex0.xy).rgb, 1.0);
}

float4 PS_Median(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetMedian(SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetSelfBilateralUpsampleXY(SampleTempTex5, SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetSelfBilateralUpsampleXY(SampleTempTex4, SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetSelfBilateralUpsampleXY(SampleTempTex3, SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_MotionStabilization(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 PixelSize = fwidth(Input.Tex0.xy);
    float2 StabilizationTex = _GlobalStabilization ? 0.5 : Input.Tex0;
    float StabilizationLOD = _GlobalStabilization ? 99.0 : _LocalStabilizationMipBias;

    // Get motion vectors
    float2 MotionVectors = CMath_Float2_FP16ToNorm(tex2Dlod(SampleStabilizationTex, float4(StabilizationTex, 0.0, StabilizationLOD)).xy);
    MotionVectors.x = _InvertWarpX ? -MotionVectors.x : MotionVectors.x;
    MotionVectors.y = _InvertWarpY ? -MotionVectors.y : MotionVectors.y;

    float2 StableTex = Input.Tex0.xy - 0.5;
    StableTex -= (MotionVectors * _WarpStrength);
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

technique CShade_MotionStabilization
<
    ui_label = "CShade · Motion Stabilization";
    ui_tooltip = "Motion stabilization effect.\n\n[ Preprocessor Definitions ]\n\nSTABILIZATION_ADDRESS:\n\n\tHow the shader renders pixels outside the texture's boundaries.\n\n\tAvailable Options:\n\t· CLAMP\n\t· MIRROR\n\t· WRAP/REPEAT\n\t· BORDER\n\nSTABILIZATION_GRID_SAMPLING:\n\n\tHow the shader filters the motion vectors used for stabilization.\n\n\tAvailable Options:\n\t· LINEAR\n\t· POINT\n\nSTABILIZATION_WARP_SAMPLING\n\n\tHow the shader filters warped pixels.\n\n\tAvailable Options:\n\t· LINEAR\n\t· POINT";
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
        PixelShader = PS_MotionStabilization;
    }
}
