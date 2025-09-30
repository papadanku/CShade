#define CSHADE_AUTOEXPOSUREBLOOM

#include "shared/cBlur.fxh"
#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*
    [ Shader Options ]
*/

#ifndef SHADER_TOGGLE_AUTOEXPOSURE
    #define SHADER_TOGGLE_AUTOEXPOSURE 1
#endif

// Bloom-specific settings
uniform int _BloomRenderMode <
    ui_category = "Main Shader";
    ui_label = "Rendering Mode";
    ui_type = "combo";
    ui_items = "Base + Bloom\0Bloom\0";
> = 0;

uniform float _BloomThreshold <
    ui_category = "Main Shader";
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.8;

uniform float _BloomSmoothing <
    ui_category = "Main Shader";
    ui_label = "Smoothing";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float _BloomIntensity <
    ui_category = "Main Shader";
    ui_label = "Intensity";
    ui_type = "slider";
    ui_step = 0.001;
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

#include "shared/cShadeHDR.fxh"
#if SHADER_TOGGLE_AUTOEXPOSURE
    uniform float _Frametime < source = "frametime"; >;
    #include "shared/cCamera.fxh"
#endif
#include "shared/cComposite.fxh"
#include "shared/cBlend.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_label = " ";
    ui_type = "radio";
    ui_text = "\nCCOMPOSITE_TOGGLE_GRADING - Enables auto exposure.\n\n\tOptions: 0 (disabled), 1 (enabled)\n\nCCOMPOSITE_TOGGLE_GRADING - Enables color grading.\n\n\tOptions: 0 (disabled), 1 (enabled)\n\n";
    ui_category_closed = false;
> = 0;

/*
    [ Textures & Samplers ]
*/

// Bloom-specific textures and samplers
CREATE_TEXTURE_POOLED(TempTex0_RGBA16F, BUFFER_SIZE_0, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex1_RGBA16F, BUFFER_SIZE_1, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex2_RGBA16F, BUFFER_SIZE_2, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex3_RGBA16F, BUFFER_SIZE_3, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RGBA16F, BUFFER_SIZE_4, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RGBA16F, BUFFER_SIZE_5, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex6_RGBA16F, BUFFER_SIZE_6, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex7_RGBA16F, BUFFER_SIZE_7, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex8_RGBA16F, BUFFER_SIZE_8, RGBA16F, 1)

CREATE_SAMPLER(SampleTempTex0, TempTex0_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex1, TempTex1_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex2, TempTex2_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex6, TempTex6_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex7, TempTex7_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex8, TempTex8_RGBA16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

#if SHADER_TOGGLE_AUTOEXPOSURE
    CREATE_TEXTURE(BloomExposureTex, int2(1, 1), R16F, 0)
    CREATE_SAMPLER(SampleBloomExposureTex, BloomExposureTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

/*
    [ Pixel Shaders ]

    Thresholding | https://github.com/keijiro/Kino [MIT]
    Tonemapping | https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/

#if SHADER_TOGGLE_AUTOEXPOSURE
    void PS_GetExposure(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float LogLuminance = tex2D(SampleTempTex8, Input.Tex0).a;
        Output = CCamera_CreateExposureTex(LogLuminance, _Frametime);
    }
#endif

// Bloom-specific functions
void PS_Prefilter(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0);
    float Luminance = 1.0;

    // Apply auto exposure to the backbuffer
    #if SHADER_TOGGLE_AUTOEXPOSURE
        // Store log luminance in the alpha channel
        if (_CCamera_MeteringType == 1)
        {
            float3 ColorArea = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, CCamera_GetSpotMeterTex(Input.Tex0)).rgb;
            Luminance = CCamera_GetLogLuminance(ColorArea.rgb);
        }
        else
        {
            Luminance = CCamera_GetLogLuminance(Color.rgb);
        }

        // Apply auto exposure to input
        float Luma = tex2D(SampleBloomExposureTex, Input.Tex0).r;
        Exposure ExposureData = CCamera_GetExposureData(Luma);
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

#define CREATE_PS_DOWNSCALE(METHOD_NAME, SAMPLER, FLICKER_FILTER) \
    void METHOD_NAME(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0) \
    { \
        Output = CBlur_Downsample6x6(SAMPLER, Input.Tex0, FLICKER_FILTER); \
    }

CREATE_PS_DOWNSCALE(PS_Downscale1, SampleTempTex0, true)
CREATE_PS_DOWNSCALE(PS_Downscale2, SampleTempTex1, false)
CREATE_PS_DOWNSCALE(PS_Downscale3, SampleTempTex2, false)
CREATE_PS_DOWNSCALE(PS_Downscale4, SampleTempTex3, false)
CREATE_PS_DOWNSCALE(PS_Downscale5, SampleTempTex4, false)
CREATE_PS_DOWNSCALE(PS_Downscale6, SampleTempTex5, false)
CREATE_PS_DOWNSCALE(PS_Downscale7, SampleTempTex6, false)
CREATE_PS_DOWNSCALE(PS_Downscale8, SampleTempTex7, false)

#define CREATE_PS_UPSCALE(METHOD_NAME, SAMPLER) \
    void METHOD_NAME(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0) \
    { \
        Output.rgb = CBlur_UpsampleTent(SAMPLER, Input.Tex0).rgb; \
        Output.a = 1.0; \
    }

CREATE_PS_UPSCALE(PS_Upscale7, SampleTempTex8)
CREATE_PS_UPSCALE(PS_Upscale6, SampleTempTex7)
CREATE_PS_UPSCALE(PS_Upscale5, SampleTempTex6)
CREATE_PS_UPSCALE(PS_Upscale4, SampleTempTex5)
CREATE_PS_UPSCALE(PS_Upscale3, SampleTempTex4)
CREATE_PS_UPSCALE(PS_Upscale2, SampleTempTex3)
CREATE_PS_UPSCALE(PS_Upscale1, SampleTempTex2)

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 BaseColor = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 NonExposedColor = BaseColor;

    // Apply auto exposure to base-color
    #if SHADER_TOGGLE_AUTOEXPOSURE
        float Luma = tex2Dlod(SampleBloomExposureTex, float4(Input.Tex0, 0.0, 99.0)).r;
        Exposure ExposureData = CCamera_GetExposureData(Luma);
        BaseColor = CCamera_ApplyAutoExposure(BaseColor.rgb, ExposureData);
    #endif

    // Bloom composition
    float3 BloomColor = tex2D(SampleTempTex1, Input.Tex0).rgb;
    BaseColor = (_BloomRenderMode == 0) ? BaseColor + (BloomColor * _BloomIntensity) : BloomColor;

    // Apply color-grading
    CComposite_ApplyOutput(BaseColor.rgb);

    // Apply overlays
    #if SHADER_TOGGLE_AUTOEXPOSURE
        float2 UnormTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
        CCAmera_ApplyExposurePeaking(BaseColor, Input.HPos.xy);
        CCamera_ApplySpotMeterOverlay(BaseColor, UnormTex, NonExposedColor);
        CCamera_ApplyAverageLumaOverlay(BaseColor, UnormTex, ExposureData);
    #endif

    Output = CBlend_OutputChannels(BaseColor.rgb, _CShade_AlphaFactor);
}

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET, IS_ADDITIVE) \
    pass \
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
    ui_label = "CShade · Auto Exposure & Bloom";
    ui_tooltip = "Adjustable bloom, auto exposure, and color-grading.";
>
{
    // Prefilter
    CREATE_PASS(CShade_VS_Quad, PS_Prefilter, TempTex0_RGBA16F, FALSE)

    // Iteratively downsample the image (RGB) and its log luminance (A) into a pyramid.
    CREATE_PASS(CShade_VS_Quad, PS_Downscale1, TempTex1_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale2, TempTex2_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale3, TempTex3_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale4, TempTex4_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale5, TempTex5_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale6, TempTex6_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale7, TempTex7_RGBA16F, FALSE)
    CREATE_PASS(CShade_VS_Quad, PS_Downscale8, TempTex8_RGBA16F, FALSE)

    /*
        Additive iterative upsampling.
        Formula: Upsample(Level[N+1]) + Level[N]
    */
    CREATE_PASS(CShade_VS_Quad, PS_Upscale7, TempTex7_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale6, TempTex6_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale5, TempTex5_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale4, TempTex4_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale3, TempTex3_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale2, TempTex2_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale1, TempTex1_RGBA16F, TRUE)

    pass Composition
    {
        ClearRenderTargets = FALSE;
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }

    /*
        Store the coarsest level of the log luminance pyramid in an accumulation texture.
        We store the coarsest level here to synchronize the auto exposure Luma texture in the PS_Prefilter and PS_Main passes.
    */
    #if SHADER_TOGGLE_AUTOEXPOSURE
        pass CCamera_CreateExposureTex
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
