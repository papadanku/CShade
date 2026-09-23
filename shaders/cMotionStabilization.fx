#define CSHADE_MOTIONSTABILIZATION

/*
    This shader implements a motion stabilization effect, using optical flow to counter camera shake or unwanted movement in the image. It calculates motion vectors via the Lucas-Kanade method and applies a reverse warp to stabilize the scene. Users can invert stabilization along X or Y axes, choose global or local stabilization, adjust warp strength, and apply temporal smoothing. The shader also includes cosmetic geometric transformations like scaling, rotation, and translation, along with image-based scaling options and debug views for motion vectors.
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotion.fxh"

/* Shader Options */

#ifndef IMPORT_CSHARES_MOTION_VECTORS
    #define IMPORT_CSHARES_MOTION_VECTORS 0
#endif

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

uniform float _FrameTime <
    source = "frametime";
    ui_tooltip = "The time elapsed since the last frame, used for time-based effects.";
>;

uniform int _DisplayMode <
    ui_items = "Output\0Debug · Quadrant\0Debug · Motion Vector Direction\0Debug · Motion Vector Magnitude\0";
    ui_label = "Display Mode";
    ui_type = "combo";
    ui_tooltip = "Controls how the optical flow information is displayed, including different debug views.";
> = 0;

uniform float2 _WarpStrength <
    ui_label = "Stabilization Warp Strength";
    ui_max = 8.0;
    ui_min = -8.0;
    ui_type = "slider";
    ui_tooltip = "Controls the intensity of the image warping applied for motion stabilization.";
> = 1.0;

uniform float _MipBias <
    ui_text = "OPTICAL FLOW";
    ui_label = "Optical Flow Mipmap Level";
    ui_max = 3.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for sampling the optical flow map, affecting the detail and smoothness of the flow vectors.";
> = 0.0;

uniform int _GeometricTransformOrder <
    ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0";
    ui_label = "Geometric Transform Order";
    ui_text = "GEOMETRIC TRANSFORMATION";
    ui_type = "combo";
    ui_tooltip = "Defines the order in which scaling, rotation, and translation operations are applied to the image.";
> = 0;

uniform float _Angle <
    ui_label = "Geometric Rotation";
    ui_type = "drag";
    ui_tooltip = "Controls the rotation of the image around its center.";
> = 0.0;

uniform float2 _Translate <
    ui_label = "Geometric Translation";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical translation (position) of the image.";
> = 0.0;

uniform float2 _Scale <
    ui_label = "Geometric Scale";
    ui_type = "drag";
    ui_tooltip = "Controls the horizontal and vertical scaling of the image.";
> = 1.0;

uniform int _ScaleByImage <
    ui_items = "Luminance\0Chromaticity\0Disabled\0";
    ui_label = "Cosmetic Scaling Method";
    ui_text = "COSMETIC - SCALE BY COLOR";
    ui_type = "combo";
    ui_tooltip = "Selects a color channel from the image to use as a scalar for cosmetic scaling effects.";
> = 2;

uniform float _ScaleByImageIntensity <
    ui_label = "Cosmetic Scaling Intensity";
    ui_max = 8.0;
    ui_min = -8.0;
    ui_type = "drag";
    ui_tooltip = "Controls the intensity of the cosmetic scaling effect driven by image content.";
> = 1.0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

CSHADE_UI_PREPROCESSOR_GUIDE(
    "\nSHADER_BACKBUFFER_ADDRESS - How the shader renders pixels outside the texture's boundaries.\n\n\tOptions: CLAMP, MIRROR, WRAP/REPEAT, BORDER\n\nSHADER_MOTION_VECTORS_SAMPLING - How the shader filters the motion vectors used for stabilization.\n\n\tOptions: LINEAR, POINT\n\nSHADER_DISPLACEMENT_SAMPLING - How the shader filters warped pixels.\n\n\tOptions: LINEAR, POINT\n\nSHADER_COSMETIC_SAMPLING - How the shader filters the image content texture used for color-based displacement.\n\n\tOptions: LINEAR, POINT\n\n"
)

/* Textures & Samplers */

#if IMPORT_CSHARES_MOTION_VECTORS
    CSHADE_CREATE_TEXTURE(CShade_Mainframe_MotionVectors, CSHADE_BUFFER_SIZE_2, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_B, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_B, CSHADE_BUFFER_SIZE_4, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_5_A, CSHADE_BUFFER_SIZE_5, RG16F, 1)

    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_2, CShade_Mainframe_MotionVectors, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_3, SharedTex_RG16F_3_B, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_4, SharedTex_RG16F_4_B, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_5, SharedTex_RG16F_5_A, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
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

    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowStabilization_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowStabilization_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowStabilization_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_FlowStabilization_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)

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

    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowStabilization_2, PreviousFrameTex_FlowStabilization_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowStabilization_3, PreviousFrameTex_FlowStabilization_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowStabilization_4, PreviousFrameTex_FlowStabilization_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_FlowStabilization_5, PreviousFrameTex_FlowStabilization_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_2, SharedTex_RG16F_2_B, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_3, SharedTex_RG16F_3_B, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_4, SharedTex_RG16F_4_B, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_5, SharedTex_RG16F_5_A, SHADER_MOTION_VECTORS_SAMPLING, SHADER_MOTION_VECTORS_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

CSHADE_CREATE_SRGB_SAMPLER(SampleStableTex, CShade_ColorTex, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, SHADER_BACKBUFFER_ADDRESS, SHADER_BACKBUFFER_ADDRESS, SHADER_BACKBUFFER_ADDRESS)

#if !IMPORT_CSHARES_MOTION_VECTORS

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
        Output = CMotionEstimation_GetLucasKanade(true, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowStabilization_5, SampleSharedTex_RGB10A2_5);
    }

    void PS_LucasKanade3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_5_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowStabilization_4, SampleSharedTex_RGB10A2_4);
    }

    void PS_LucasKanade2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_4_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowStabilization_3, SampleSharedTex_RGB10A2_3);
    }

    void PS_LucasKanade1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_3_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_FlowStabilization_2, SampleSharedTex_RGB10A2_2);
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

/* Pixel Shaders: Output */

float2 GetMotionVectors(float4 Tex)
{
    float2 MipLevels[4];
    MipLevels[0] = tex2Dlod(SampleMotionVectorTex_2, Tex).xy;
    MipLevels[1] = tex2Dlod(SampleMotionVectorTex_3, Tex).xy;
    MipLevels[2] = tex2Dlod(SampleMotionVectorTex_4, Tex).xy;
    MipLevels[3] = tex2Dlod(SampleMotionVectorTex_5, Tex).xy;

    // Expand the clamp range to cover 4 levels (0.0 -> 3.0)
    float Bias = clamp(_MipBias, 0.0, 3.0);

    [flatten]
    if (Bias <= 1.0)
    {
        // Smoothly lerp between Level 0 and Level 1 (bias: 0.0 -> 1.0)
        return lerp(MipLevels[0], MipLevels[1], Bias);
    }
    else if (Bias <= 2.0)
    {
        // Smoothly lerp between Level 1 and Level 2 (bias: 1.0 -> 2.0)
        return lerp(MipLevels[1], MipLevels[2], Bias - 1.0);
    }
    else
    {
        // Smoothly lerp between Level 2 and Level 3 (bias: 2.0 -> 3.0)
        return lerp(MipLevels[2], MipLevels[3], Bias - 2.0);
    }
}

float4 GetMotionStabilization(CShade_VS2PS_Quad Input, float2 MotionVectors)
{
    float2 StableTex = Input.Tex0.xy - 0.5;
    StableTex -= (MotionVectors * _WarpStrength);
    StableTex += 0.5;

    // Apply Geometric Transform
    const float Pi2 = CMath_GetPi() * 2.0;
    CMath_ApplyGeometricTransform(StableTex, _GeometricTransformOrder, _Angle * Pi2, _Translate, _Scale, true);

    return tex2Dlod(SampleStableTex, CShade_PadFloat2(StableTex));
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    CMath_TexGrid Grid = CMath_GetTexGrid(Input.Tex0, 2);

    if (_DisplayMode == 1)
    {
        Input.Tex0 = Grid.Frac;
    }

    // Get needed LOD for shader

    // Gather textures
    float4 Image = tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(Input.Tex0));
    float4 MotionVectorsTex = CShade_PadFloat2(Input.Tex0);
    float2 MotionVectors = CMath_FP16toSNORM_FLT2(GetMotionVectors(MotionVectorsTex).xy);

    // Compute motion vector masking
    float Luma = max(max(Image.r, Image.g), Image.b);
    float3 Chroma = (abs(Luma) > 0.0) ? Image.rgb / Luma: 1.0;
    float ScaleMask = lerp(Luma, distance(Chroma, float3(1.0, 1.0, 1.0)), _ScaleByImage);
    ScaleMask = (_ScaleByImage != 2) ? ScaleMask * _ScaleByImageIntensity : 1.0;
    float4 ShaderOutput = GetMotionStabilization(Input, MotionVectors * ScaleMask);

    switch (_DisplayMode)
    {
        case 0:
            Output.rgb = ShaderOutput.rgb;
            break;
        case 1:
            Output.rgb = CMotionEstimation_GetDebugQuadrant(Image.rgb, ShaderOutput.rgb, MotionVectors, Grid.Index);
            break;
        case 2:
            Output.rgb = CMotionEstimation_GetMotionVectorRGB(MotionVectors);
            break;
        case 3:
            Output.rgb = length(MotionVectors);
            break;
        default:
            Output.rgb = Image.rgb;
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

#if IMPORT_CSHARES_MOTION_VECTORS
    #define SHADER_UI_LABEL_EXT " & CShares"
#else
    #define SHADER_UI_LABEL_EXT ""
#endif

#define SHADER_UI_LABEL "CShade" SHADER_UI_LABEL_EXT " | Motion Stabilization"

technique CShade_MotionStabilization
<
    ui_label = SHADER_UI_LABEL;
    ui_tooltip = "Motion stabilization effect.";
>
{

    #if !IMPORT_CSHARES_MOTION_VECTORS
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
        TEMPLATE_PASS(CopyCoarse, CShade_VS_Quad, PS_CopyCoarse, PreviousFrameTex_FlowStabilization_5)
        TEMPLATE_PASS_MRT2(Upsample3_Copy3, CShade_VS_Quad, PS_Upsample3_Copy3, SharedTex_RG16F_4_B, PreviousFrameTex_FlowStabilization_4)
        TEMPLATE_PASS_MRT2(Upsample2_Copy2, CShade_VS_Quad, PS_Upsample2_Copy2, SharedTex_RG16F_3_B, PreviousFrameTex_FlowStabilization_3)
        TEMPLATE_PASS_MRT2(Upsample1_Copy1, CShade_VS_Quad, PS_Upsample1_Copy1, SharedTex_RG16F_2_B, PreviousFrameTex_FlowStabilization_2)
    #endif

    pass MotionStabilization
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
