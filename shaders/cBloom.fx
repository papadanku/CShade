#define CSHADE_BLOOM

/*
    This shader combines an auto-exposure effect with a bloom effect. It dynamically adjusts image brightness and adds a radiant glow to bright areas. The shader prefilters the scene, performs iterative downsampling and upsampling to create the bloom, and then composes the final image, optionally applying auto-exposure and color grading.
*/

#include "shared/cBlur.fxh"
#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*  Shader Options  */

// Bloom-specific settings
uniform int _BloomRenderMode <
    ui_items = "Base + Bloom\0Bloom\0";
    ui_label = "Bloom Rendering Mode";
    ui_type = "combo";
    ui_tooltip = "Determines how the bloom effect is rendered, either combined with the base image or as a standalone bloom.";
> = 0;

uniform float _BloomThreshold <
    ui_label = "Bloom Threshold";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Sets the minimum brightness level for pixels to contribute to the bloom effect. Only pixels brighter than this value will bloom.";
> = 0.8;

uniform float _BloomSmoothing <
    ui_label = "Bloom Smoothing";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the smoothness of the transition between non-blooming and blooming areas, affecting how soft the bloom edges appear.";
> = 0.5;

uniform float _BloomIntensity <
    ui_label = "Bloom Intensity";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_step = 0.001;
    ui_type = "slider";
    ui_tooltip = "Adjusts the overall strength or brightness of the bloom effect.";
> = 0.5;

#ifndef CSHADE_APPLY_AUTO_EXPOSURE
    #define CSHADE_APPLY_AUTO_EXPOSURE 1
#endif
#ifndef CSHADE_APPLY_TONEMAP
    #define CSHADE_APPLY_TONEMAP 1
#endif
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/*
    [ Textures & Samplers ]
*/

// Bloom-specific textures and samplers
CSHADE_CREATE_TEXTURE_POOLED(SharedTex0_RGBA16F, CSHADE_BUFFER_SIZE_0, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex1_RGBA16F, CSHADE_BUFFER_SIZE_1, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex2_RGBA16F, CSHADE_BUFFER_SIZE_2, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex3_RGBA16F, CSHADE_BUFFER_SIZE_3, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex4_RGBA16F, CSHADE_BUFFER_SIZE_4, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex5_RGBA16F, CSHADE_BUFFER_SIZE_5, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex6_RGBA16F, CSHADE_BUFFER_SIZE_6, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex7_RGBA16F, CSHADE_BUFFER_SIZE_7, RGBA16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(SharedTex8_RGBA16F, CSHADE_BUFFER_SIZE_8, RGBA16F, 1)

CSHADE_CREATE_SAMPLER(SampleSharedTex0, SharedTex0_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex1, SharedTex1_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex2, SharedTex2_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex3, SharedTex3_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex4, SharedTex4_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex5, SharedTex5_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex6, SharedTex6_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex7, SharedTex7_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleSharedTex8, SharedTex8_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

#if CSHADE_APPLY_AUTO_EXPOSURE
    CSHADE_CREATE_TEXTURE(BloomExposureTex, int2(1, 1), R16F, 0)
    CSHADE_CREATE_SAMPLER(SampleBloomExposureTex, BloomExposureTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

/* Pixel Shaders */

/*
    Thresholding | https://github.com/keijiro/Kino [MIT]
    Tonemapping | https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/

#if CSHADE_APPLY_AUTO_EXPOSURE
    void PS_GetExposure(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float LogLuminance = tex2D(SampleSharedTex8, Input.Tex0).a;
        Output = CCamera_CreateExposureTex(LogLuminance);
        Output = CMath_GetOutOfBounds(Input.Tex0) ? 0.0 : Output;
    }
#endif

// Bloom-specific functions
void PS_Prefilter(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float Luminance = 1.0;

    // Apply auto exposure to the backbuffer
    #if CSHADE_APPLY_AUTO_EXPOSURE
        // Store log luminance in the alpha channel
        if (_CCamera_MeteringType == 1)
        {
            float3 ColorArea = tex2D(CShade_SampleColorTex, CCamera_GetSpotMeterTex(Input.Tex0)).rgb;
            Luminance = CCamera_GetLogLuminance(ColorArea.rgb);
        }
        else
        {
            Luminance = CCamera_GetLogLuminance(Color.rgb);
        }

        // Apply auto exposure to input
        float Luma = tex2D(SampleBloomExposureTex, Input.Tex0).r;
        CCamera_Exposure ExposureData = CCamera_GetExposureData(Luma);
        Color = CCamera_ApplyAutoExposure(Color.rgb, ExposureData);
    #endif

    // Thresholding phase
    const float Knee = mad(_BloomThreshold, _BloomSmoothing, 1e-5);
    const float3 Curve = float3(_BloomThreshold - Knee, Knee * 2.0, 0.25 / Knee);

    // Under-threshold
    float Brightness = CColor_RGBtoLuma(Color.rgb, 3);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _BloomThreshold) / max(Brightness, 1e-10);

    Output.rgb = Color.rgb;
    Output.a = Luminance;
}

#define TEMPLATE_PS_DOWNSCALE(METHOD_NAME, SAMPLER, FLICKER_FILTER) \
    void METHOD_NAME(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0) \
    { \
        Output = CBlur_Downsample6x6(SAMPLER, Input.Tex0, FLICKER_FILTER); \
    }

TEMPLATE_PS_DOWNSCALE(PS_Downscale1, SampleSharedTex0, true)
TEMPLATE_PS_DOWNSCALE(PS_Downscale2, SampleSharedTex1, false)
TEMPLATE_PS_DOWNSCALE(PS_Downscale3, SampleSharedTex2, false)
TEMPLATE_PS_DOWNSCALE(PS_Downscale4, SampleSharedTex3, false)
TEMPLATE_PS_DOWNSCALE(PS_Downscale5, SampleSharedTex4, false)
TEMPLATE_PS_DOWNSCALE(PS_Downscale6, SampleSharedTex5, false)
TEMPLATE_PS_DOWNSCALE(PS_Downscale7, SampleSharedTex6, false)
TEMPLATE_PS_DOWNSCALE(PS_Downscale8, SampleSharedTex7, false)

#define TEMPLATE_PS_UPSCALE(METHOD_NAME, SAMPLER) \
    void METHOD_NAME(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0) \
    { \
        Output.rgb = CBlur_UpsampleTent(SAMPLER, Input.Tex0).rgb; \
        Output.a = 1.0; \
    }

TEMPLATE_PS_UPSCALE(PS_Upscale7, SampleSharedTex8)
TEMPLATE_PS_UPSCALE(PS_Upscale6, SampleSharedTex7)
TEMPLATE_PS_UPSCALE(PS_Upscale5, SampleSharedTex6)
TEMPLATE_PS_UPSCALE(PS_Upscale4, SampleSharedTex5)
TEMPLATE_PS_UPSCALE(PS_Upscale3, SampleSharedTex4)
TEMPLATE_PS_UPSCALE(PS_Upscale2, SampleSharedTex3)
TEMPLATE_PS_UPSCALE(PS_Upscale1, SampleSharedTex2)

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 BaseColor = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 NonExposedColor = BaseColor;

    // Apply auto exposure to base-color
    #if CSHADE_APPLY_AUTO_EXPOSURE
        float Luma = tex2Dlod(SampleBloomExposureTex, float4(Input.Tex0, 0.0, 99.0)).r;
        CCamera_Exposure ExposureData = CCamera_GetExposureData(Luma);
        BaseColor = CCamera_ApplyAutoExposure(BaseColor.rgb, ExposureData);
    #endif

    // Bloom composition
    float3 BloomColor = tex2D(SampleSharedTex1, Input.Tex0).rgb;
    BaseColor = (_BloomRenderMode == 0) ? BaseColor + (BloomColor * _BloomIntensity) : BloomColor;

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(BaseColor, _CShade_AlphaFactor);
    #else
        Output = float4(BaseColor, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);

    // Apply (optional) overlays
    #if CSHADE_APPLY_AUTO_EXPOSURE
        float2 UnormTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
        CCamera_ApplySpotMeterOverlay(Output.rgb, UnormTex, NonExposedColor);
        CCamera_ApplyAverageLumaOverlay(Output.rgb, UnormTex, ExposureData);
    #endif
}

#define TEMPLATE_PASS(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET, IS_ADDITIVE) \
    pass NAME \
    { \
        ClearRenderTargets = FALSE; \
        BlendEnable = IS_ADDITIVE; \
        BlendOp = ADD; \
        SrcBlend = ONE; \
        DestBlend = ONE; \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_AutoExposureBloom
<
    ui_label = "CShade | Bloom";
    ui_tooltip = "Adjustable bloom with auto-exposure.";
>
{
    TEMPLATE_PASS(Prefilter, CShade_VS_Quad, PS_Prefilter, SharedTex0_RGBA16F, FALSE)

    // Iteratively downsample the image (RGB) and its log luminance (A) into a pyramid.
    TEMPLATE_PASS(Downsample1, CShade_VS_Quad, PS_Downscale1, SharedTex1_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample2, CShade_VS_Quad, PS_Downscale2, SharedTex2_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample3, CShade_VS_Quad, PS_Downscale3, SharedTex3_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample4, CShade_VS_Quad, PS_Downscale4, SharedTex4_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample5, CShade_VS_Quad, PS_Downscale5, SharedTex5_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample6, CShade_VS_Quad, PS_Downscale6, SharedTex6_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample7, CShade_VS_Quad, PS_Downscale7, SharedTex7_RGBA16F, FALSE)
    TEMPLATE_PASS(Downsample8, CShade_VS_Quad, PS_Downscale8, SharedTex8_RGBA16F, FALSE)

    /*
        Additive iterative upsampling.
        Formula: Upsample(Level[N+1]) + Level[N]
    */
    TEMPLATE_PASS(Upscale7, CShade_VS_Quad, PS_Upscale7, SharedTex7_RGBA16F, TRUE)
    TEMPLATE_PASS(Upscale6, CShade_VS_Quad, PS_Upscale6, SharedTex6_RGBA16F, TRUE)
    TEMPLATE_PASS(Upscale5, CShade_VS_Quad, PS_Upscale5, SharedTex5_RGBA16F, TRUE)
    TEMPLATE_PASS(Upscale4, CShade_VS_Quad, PS_Upscale4, SharedTex4_RGBA16F, TRUE)
    TEMPLATE_PASS(Upscale3, CShade_VS_Quad, PS_Upscale3, SharedTex3_RGBA16F, TRUE)
    TEMPLATE_PASS(Upscale2, CShade_VS_Quad, PS_Upscale2, SharedTex2_RGBA16F, TRUE)
    TEMPLATE_PASS(Upscale1, CShade_VS_Quad, PS_Upscale1, SharedTex1_RGBA16F, TRUE)

    pass Composition
    {
        ClearRenderTargets = FALSE;
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }

    /*
        Store the coarsest level of the log luminance pyramid in an accumulation texture.
        We store the coarsest level here to synchronize the auto exposure Luma texture in the PS_Prefilter and PS_Main passes.
    */
    #if CSHADE_APPLY_AUTO_EXPOSURE
        pass CreateExposureTexture
        {
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = SRCALPHA;
            DestBlend = INVSRCALPHA;

            VertexShader = CShade_VS_Quad;
            PixelShader = PS_GetExposure;
            RenderTarget0 = BloomExposureTex;
        }
    #endif
}
