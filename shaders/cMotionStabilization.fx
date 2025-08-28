#define CSHADE_MOTIONSTABILIZATION

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/*
    [Shader Options]
*/

#ifndef SHADER_STABILIZATION_ADDRESS
    #define SHADER_STABILIZATION_ADDRESS BORDER
#endif

#ifndef SHADER_STABILIZATION_GRID_SAMPLING
    #define SHADER_STABILIZATION_GRID_SAMPLING LINEAR
#endif

#ifndef SHADER_STABILIZATION_WARP_SAMPLING
    #define SHADER_STABILIZATION_WARP_SAMPLING POINT
#endif

uniform float _FrameTime < source = "frametime"; > ;

uniform int _DisplayMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Output\0Debug · Quadrant\0Debug · Motion Vector Direction\0Debug · Motion Vector Magnitude\0";
> = 0;

uniform bool _InvertWarpX <
    ui_category = "Motion Stabilization";
    ui_label = "Invert X Axis";
    ui_type = "radio";
> = false;

uniform bool _InvertWarpY <
    ui_category = "Motion Stabilization";
    ui_label = "Invert Y Axis";
    ui_type = "radio";
> = false;

uniform bool _GlobalStabilization <
    ui_category = "Motion Stabilization";
    ui_label = "Enable Global Stabilization";
    ui_type = "radio";
> = false;

uniform float _LocalStabilizationMipBias <
    ui_category = "Motion Stabilization";
    ui_label = "Mipmap Level";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
> = 3.5;

uniform float2 _WarpStrength <
    ui_category = "Motion Stabilization";
    ui_label = "Warping Strength";
    ui_type = "slider";
    ui_min = -8.0;
    ui_max = 8.0;
> = 1.0;

uniform float _BlendFactor <
    ui_category = "Motion Stabilization";
    ui_label = "Temporal Smoothing";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 8.0;
> = 1.0;

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
    ui_label = "Scale";
    ui_type = "drag";
> = 1.0;

uniform int _ScaleByImage <
    ui_category = "Cosmetic · Scale by Image Content";
    ui_label = "Scalar";
    ui_type = "combo";
    ui_items = "Radial (Luma)\0Polar Angle (Chroma 1)\0Azimuthal Angle (Chroma 2)\0Disabled\0";
> = 3;

uniform float _ScaleByImageLOD <
    ui_category = "Cosmetic · Scale by Image Content";
    ui_label = "Mipmap Level";
    ui_type = "drag";
> = 0.5;

uniform float _ScaleByImageIntensity <
    ui_category = "Cosmetic · Scale by Image Content";
    ui_label = "Intensity";
    ui_type = "drag";
    ui_min = -8.0;
    ui_max = 8.0;
> = 1.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#include "shared/cPreprocessorGuide.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide · Shader";
    ui_label = " ";
    ui_type = "radio";
    ui_text = "\nSHADER_STABILIZATION_ADDRESS - How the shader renders pixels outside the texture's boundaries.\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_STABILIZATION_GRID_SAMPLING - How the shader filters the motion vectors used for stabilization.\n\n\tOptions: LINEAR, POINT\n\nSHADER_STABILIZATION_WARP_SAMPLING - How the shader filters warped pixels.\n\n\tOptions: LINEAR, POINT\n\n";
    ui_category_closed = false;
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

CREATE_SAMPLER(SampleStabilizationTex, TempTex2_RG16F, SHADER_STABILIZATION_GRID_SAMPLING, SHADER_STABILIZATION_GRID_SAMPLING, SHADER_STABILIZATION_GRID_SAMPLING, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleStableTex, CShade_ColorTex, SHADER_STABILIZATION_WARP_SAMPLING, SHADER_STABILIZATION_WARP_SAMPLING, SHADER_STABILIZATION_WARP_SAMPLING, SHADER_STABILIZATION_ADDRESS, SHADER_STABILIZATION_ADDRESS, SHADER_STABILIZATION_ADDRESS)


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
    return CMotionEstimation_GetLucasKanade(true, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

float2 PS_LucasKanade3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex5).xy;
    return CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

float2 PS_LucasKanade2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex4).xy;
    return CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

float4 PS_LucasKanade1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex3).xy;
    float2 Flow = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
    const float BlendScale = _BlendFactor + 1.0;
    return float4(Flow * BlendScale, 0.0, 1.0 / BlendScale);
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

    return CShadeHDR_Tex2D_InvTonemap(SampleStableTex, StableTex);
}

float4 PS_MotionStabilization(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    CMath_TexGrid Grid = CMath_GetTexGrid(Input.Tex0, 2);

    if (_DisplayMode == 1)
    {
        Input.Tex0 = Grid.Frac;
    }

    // Get needed LOD for shader
    float2 StabilizationTex = _GlobalStabilization ? 0.5 : Input.Tex0;
    float StabilizationLOD = _GlobalStabilization ? 99.0 : _LocalStabilizationMipBias;

    float4 Base = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0);
    float4 Image = tex2Dlod(SampleTempTex1, float4(Input.Tex0, 0.0, _ScaleByImageLOD));
    float2 MotionVectors = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleStabilizationTex, float4(StabilizationTex, 0.0, StabilizationLOD)).xy);
    float4 ShaderOutput = GetMotionStabilization(Input, MotionVectors * Image[_ScaleByImage] * _ScaleByImageIntensity);

    float4 OutputColor = float4(0.0, 0.0, 0.0, 1.0);

    switch (_DisplayMode)
    {
        case 0:
            OutputColor.rgb = ShaderOutput.rgb;
            break;
        case 1:
            OutputColor.rgb = CMotionEstimation_GetDebugQuadrant(Base.rgb, ShaderOutput.rgb, MotionVectors, Grid.Index);
            break;
        case 2:
            OutputColor.rgb = CMotionEstimation_GetMotionVectorRGB(MotionVectors);
            break;
        case 3:
            OutputColor.rgb = length(MotionVectors);
            break;
        default:
            OutputColor.rgb = Base.rgb;
            break;
    }

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
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
        SrcBlend = SRCALPHA;
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
        PixelShader = PS_MotionStabilization;
    }
}
