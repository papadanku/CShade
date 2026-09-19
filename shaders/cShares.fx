
/* Shader Options */

#ifndef CSHARES_EXPORT_MOTION_VECTORS
    #define CSHARES_EXPORT_MOTION_VECTORS 1
#endif

#define CSHADE_APPLY_VIGNETTE 0
#define CSHADE_APPLY_GRAIN 0
#define CSHADE_APPLY_DITHER 0
#define CSHADE_DEBUG_PEAKING 0
#define CSHADE_APPLY_SWIZZLE 0

#include "shared/cShade.fxh"

#if CSHARES_EXPORT_MOTION_VECTORS
    #include "shared/cColor.fxh"
    #include "shared/cBlur.fxh"
    #include "shared/cMotionEstimation.fxh"
#endif

#if CSHARES_EXPORT_MOTION_VECTORS
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_1, CSHADE_BUFFER_SIZE_1, RGB10A2, 1)

    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_5_A, CSHADE_BUFFER_SIZE_5, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_A, CSHADE_BUFFER_SIZE_4, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_A, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_2_A, CSHADE_BUFFER_SIZE_2, RG16F, 1)

    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_B, CSHADE_BUFFER_SIZE_4, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_B, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE(CShade_Mainframe_MotionVectors, CSHADE_BUFFER_SIZE_2, RG16F, 1)

    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Mainframe_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Mainframe_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Mainframe_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Mainframe_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_5, SharedTex_RGB10A2_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_4, SharedTex_RGB10A2_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_3, SharedTex_RGB10A2_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_2, SharedTex_RGB10A2_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_1, SharedTex_RGB10A2_1, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_5_A, SharedTex_RG16F_5_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_4_A, SharedTex_RG16F_4_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_3_A, SharedTex_RG16F_3_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_2_A, SharedTex_RG16F_2_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_4_B, SharedTex_RG16F_4_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_3_B, SharedTex_RG16F_3_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_2_B, CShade_Mainframe_MotionVectors, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Mainframe_2, PreviousFrameTex_Mainframe_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Mainframe_3, PreviousFrameTex_Mainframe_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Mainframe_4, PreviousFrameTex_Mainframe_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Mainframe_5, PreviousFrameTex_Mainframe_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

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
        Output = CMotionEstimation_GetLucasKanade(true, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Mainframe_5, SampleSharedTex_RGB10A2_5);
    }

    void PS_LucasKanade3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_5_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Mainframe_4, SampleSharedTex_RGB10A2_4);
    }

    void PS_LucasKanade2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_4_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Mainframe_3, SampleSharedTex_RGB10A2_3);
    }

    void PS_LucasKanade1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_3_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Mainframe_2, SampleSharedTex_RGB10A2_2);
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

#if CSHARES_EXPORT_MOTION_VECTORS
    #define SHADER_UI_LABEL_EXT " -> Motion Vectors"
#else
    #define SHADER_UI_LABEL_EXT ""
#endif

#define SHADER_UI_LABEL "[^ MOVE TO THE TOP ^] CShade | CShares" SHADER_UI_LABEL_EXT

technique CShade_Main
<
    ui_label = SHADER_UI_LABEL;
>
{
    #if CSHARES_EXPORT_MOTION_VECTORS
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
        TEMPLATE_PASS(CopyCoarse, CShade_VS_Quad, PS_CopyCoarse, PreviousFrameTex_Mainframe_5)
        TEMPLATE_PASS_MRT2(Upsample3_Copy3, CShade_VS_Quad, PS_Upsample3_Copy3, SharedTex_RG16F_4_B, PreviousFrameTex_Mainframe_4)
        TEMPLATE_PASS_MRT2(Upsample2_Copy2, CShade_VS_Quad, PS_Upsample2_Copy2, SharedTex_RG16F_3_B, PreviousFrameTex_Mainframe_3)
        TEMPLATE_PASS_MRT2(Upsample1_Copy1, CShade_VS_Quad, PS_Upsample1_Copy1, CShade_Mainframe_MotionVectors, PreviousFrameTex_Mainframe_2)
    #endif
}
