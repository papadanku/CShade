#define CSHADE_FLOW

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"
#include "shared/cProcedural.fxh"

/*
    [Shader Options]
*/

uniform float _MipBias <
    ui_label = "Mipmap Bias";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
> = 0.0;

uniform float _BlendFactor <
    ui_label = "Temporal Blending Factor";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 0.9;
> = 0.45;

uniform int _OutputMode <
    ui_label = "Output Mode";
    ui_type = "combo";
    ui_items = "Shading (Normalized)\0Shading (Renormalized)\0Line Integral Convolution\0Line Integral Convolution (Colored)\0";
> = 0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#ifndef RENDER_LINEAR_SAMPLED_FLOW
    #define RENDER_LINEAR_SAMPLED_FLOW 0
#endif

#if RENDER_LINEAR_SAMPLED_FLOW
    #define FLOW_SAMPLER_FILTER LINEAR
#else
    #define FLOW_SAMPLER_FILTER POINT
#endif

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

// This is for LCI.
CREATE_TEXTURE(NoiseTex, BUFFER_SIZE_0, R16, 0)
CREATE_SAMPLER(SampleNoiseTex, NoiseTex, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)

CREATE_TEXTURE(Tex2c, BUFFER_SIZE_3, RGB10A2, 8)
CREATE_SAMPLER(SampleTex2c, Tex2c, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_TEXTURE(FlowTex, BUFFER_SIZE_3, RG16F, 8)
CREATE_SAMPLER(SampleFlow, TempTex2_RG16F, FLOW_SAMPLER_FILTER, FLOW_SAMPLER_FILTER, LINEAR, CLAMP, CLAMP, CLAMP)

sampler2D SampleGuideHigh
{
    Texture = FlowTex;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

sampler2D SampleGuideLow
{
    Texture = FlowTex;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
    MipLODBias = 1.0;
};

/*
    [Pixel Shaders]
*/

float PS_GenerateNoise(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CProcedural_GetHash1(Input.HPos.xy, 0.0);
}

float4 PS_Normalize(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = sqrt(CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb);
    return float4(CColor_GetYCOCGRfromRGB(Color, true), 1.0);
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
    return float4(Flow, 0.0, _BlendFactor);
}

/*
    Postfilter median
*/

// We use MRT to immeduately copy the current blurred frame for the next frame
float4 PS_Copy(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(SampleTempTex1, Input.Tex0.xy).rgb, 1.0);
}

float4 PS_Median(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetMedian(SampleGuideHigh, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_UpsampleMotionVectors(SampleTempTex5, SampleGuideHigh, SampleGuideLow, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_UpsampleMotionVectors(SampleTempTex4, SampleGuideHigh, SampleGuideLow, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_UpsampleMotionVectors(SampleTempTex3, SampleGuideHigh, SampleGuideLow, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Shading(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 PixelSize = fwidth(Input.Tex0.xy);
    float2 Vectors = CMath_Float2_FP16ToNorm(tex2Dlod(SampleFlow, float4(Input.Tex0.xy, 0.0, _MipBias)).xy);
    float Minimal = max(PixelSize.x, PixelSize.y);

    // Encode vectors
    float3 VectorColors = normalize(float3(Vectors, Minimal));
    VectorColors.xy = (VectorColors.xy * 0.5) + 0.5;
    VectorColors.z = 1.0 - dot(VectorColors.xy, 0.5);

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
    float3 OutputColor = 0.0;

    switch (_OutputMode)
    {
        case 0:
            OutputColor = VectorColors;
            break;
        case 1:
            OutputColor = RenormalizedVectorColors;
            break;
        case 2:
            OutputColor = LIC;
            break;
        case 3:
            OutputColor = LIC * RenormalizedVectorColors;
            break;
        default:
            OutputColor = 0.0;
            break;
    }

    return float4(OutputColor, 1.0);
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

technique CShade_Flow < ui_tooltip = "Lucas-Kanade optical flow"; >
{
    // Normalize current frame
    CREATE_PASS(CShade_VS_Quad, PS_Normalize, TempTex1_RGB10A2)

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

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Shading;
    }
}
