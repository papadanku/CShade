
/*
    [Shader Options]
*/

uniform float _Frametime < source = "frametime"; >;

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Base + Bloom\0Bloom\0";
> = 0;

uniform float _Threshold <
    ui_category = "Bloom";
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.8;

uniform float _Smooth <
    ui_category = "Bloom";
    ui_label = "Smoothing";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float3 _ColorShift <
    ui_category = "Bloom";
    ui_label = "Color Shift (RGB)";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

uniform float _Intensity <
    ui_category = "Bloom";
    ui_label = "Intensity";
    ui_type = "slider";
    ui_step = 0.001;
    ui_min = 0.0;
    ui_max = 2.0;
> = 1.0;

#include "shared/cBlur.fxh"
#include "shared/cMath.fxh"

#define INCLUDE_CCAMERA_INPUT
#define INCLUDE_CCAMERA_OUTPUT
#include "shared/cCamera.fxh"

#define INCLUDE_CTONEMAP_OUTPUT
#include "shared/cTonemap.fxh"

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

#ifndef USE_AUTOEXPOSURE
    #define USE_AUTOEXPOSURE 1
#endif

/*
    [Textures & Samplers]
*/

#if USE_AUTOEXPOSURE
    CREATE_TEXTURE(ExposureTex, int2(1, 1), R16F, 0)
    CREATE_SAMPLER(SampleExposureTex, ExposureTex, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

CREATE_TEXTURE_POOLED(TempTex0_RGBA16F, BUFFER_SIZE_0, RGBA16F, 8)
CREATE_TEXTURE_POOLED(TempTex1_RGBA16F, BUFFER_SIZE_1, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex2_RGBA16F, BUFFER_SIZE_2, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex3_RGBA16F, BUFFER_SIZE_3, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RGBA16F, BUFFER_SIZE_4, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RGBA16F, BUFFER_SIZE_5, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex6_RGBA16F, BUFFER_SIZE_6, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex7_RGBA16F, BUFFER_SIZE_7, RGBA16F, 1)
CREATE_TEXTURE_POOLED(TempTex8_RGBA16F, BUFFER_SIZE_8, RGBA16F, 1)

CREATE_SAMPLER(SampleTempTex0, TempTex0_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex1, TempTex1_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex2, TempTex2_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex6, TempTex6_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex7, TempTex7_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex8, TempTex8_RGBA16F, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
    ---
    Thresholding: https://github.com/keijiro/Kino [MIT]
    Tonemapping: https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/

float4 PS_Prefilter(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);

    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);

    // Apply auto-exposure backbuffer
    #if USE_AUTOEXPOSURE
        float Luma = tex2D(SampleExposureTex, Input.Tex0).r;
        Exposure ExposureData = CCamera_GetExposureData(Luma);
        Color = CCamera_ApplyAutoExposure(Color.rgb, ExposureData);
    #endif

    // Store log luminance in alpha channel
    float LogLuminance = GetLogLuminance(Color.rgb);

    // Under-threshold
    float Brightness = CMath_Float1_Med3(Color.r, Color.g, Color.b);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);

    return float4(Color.rgb * _ColorShift, LogLuminance);
}

#define CREATE_PS_DOWNSCALE(METHOD_NAME, SAMPLER, FLICKER_FILTER) \
    float4 METHOD_NAME(CShade_VS2PS_Quad Input) : SV_TARGET0 \
    { \
        return CBlur_Downsample6x6(SAMPLER, Input.Tex0, FLICKER_FILTER); \
    }

CREATE_PS_DOWNSCALE(PS_Downscale1, SampleTempTex0, true)
CREATE_PS_DOWNSCALE(PS_Downscale2, SampleTempTex1, false)
CREATE_PS_DOWNSCALE(PS_Downscale3, SampleTempTex2, false)
CREATE_PS_DOWNSCALE(PS_Downscale4, SampleTempTex3, false)
CREATE_PS_DOWNSCALE(PS_Downscale5, SampleTempTex4, false)
CREATE_PS_DOWNSCALE(PS_Downscale6, SampleTempTex5, false)
CREATE_PS_DOWNSCALE(PS_Downscale7, SampleTempTex6, false)
CREATE_PS_DOWNSCALE(PS_Downscale8, SampleTempTex7, false)

float4 PS_GetExposure(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float LogLuminance = tex2D(SampleTempTex8, Input.Tex0).a;
    return CCamera_CreateExposureTex(LogLuminance, _Frametime);
}

#define CREATE_PS_UPSCALE(METHOD_NAME, SAMPLER) \
    float4 METHOD_NAME(CShade_VS2PS_Quad Input) : SV_TARGET0 \
    { \
        return float4(CBlur_UpsampleTent(SAMPLER, Input.Tex0).rgb, 1.0); \
    }

CREATE_PS_UPSCALE(PS_Upscale7, SampleTempTex8)
CREATE_PS_UPSCALE(PS_Upscale6, SampleTempTex7)
CREATE_PS_UPSCALE(PS_Upscale5, SampleTempTex6)
CREATE_PS_UPSCALE(PS_Upscale4, SampleTempTex5)
CREATE_PS_UPSCALE(PS_Upscale3, SampleTempTex4)
CREATE_PS_UPSCALE(PS_Upscale2, SampleTempTex3)
CREATE_PS_UPSCALE(PS_Upscale1, SampleTempTex2)

float4 PS_Composite(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 BaseColor = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 BloomColor = tex2D(SampleTempTex1, Input.Tex0).rgb;

    // Apply auto-exposure backbuffer
    #if USE_AUTOEXPOSURE
        float Luma = tex2D(SampleExposureTex, Input.Tex0).r;
        Exposure ExposureData = CCamera_GetExposureData(Luma);
        BaseColor = CCamera_ApplyAutoExposure(BaseColor.rgb, ExposureData);
    #endif

    // Bloom composition
    float3 Color = 0.0;
    switch (_RenderMode)
    {
        case 0:
            Color = BaseColor + (BloomColor * _Intensity);
            break;
        case 1:
            Color = BloomColor * _Intensity;
            break;
    }

    // Apply tonemapping
    Color = CTonemap_ApplyOutputTonemap(Color);

    return CBlend_OutputChannels(float4(Color, _CShadeAlphaFactor));
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

technique CShade_Bloom < ui_tooltip = "Dual-Kawase bloom with built-in autoexposure"; >
{
    // Prefilter
    CREATE_PASS(CShade_VS_Quad, PS_Prefilter, TempTex0_RGBA16F, FALSE)

    // Iteratively downsample the image (RGB) and its log luminance (A) into a "pyramid"
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

        Formula: Upsample(Level[N+1]) + Level[N])
                 ^^^^^^^^^              ^^^^^^^^^
                 Left-Side              Right-Side
    */
    CREATE_PASS(CShade_VS_Quad, PS_Upscale7, TempTex7_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale6, TempTex6_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale5, TempTex5_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale4, TempTex4_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale3, TempTex3_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale2, TempTex2_RGBA16F, TRUE)
    CREATE_PASS(CShade_VS_Quad, PS_Upscale1, TempTex1_RGBA16F, TRUE)

    pass
    {
        ClearRenderTargets = FALSE;
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Composite;
    }

    // Take the lowest level of the log luminance in the pyramid and make an accumulation texture
    #if USE_AUTOEXPOSURE
        pass CCamera_CreateExposureTex
        {
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = SRCALPHA;
            DestBlend = INVSRCALPHA;

            VertexShader = CShade_VS_Quad;
            PixelShader = PS_GetExposure;
            RenderTarget0 = ExposureTex;
        }
    #endif
}
