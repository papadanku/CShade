#define CSHADE_RAYSCHISM

#include "shared/cBlur.fxh"
#include "shared/cColor.fxh"
#include "shared/cMath.fxh"
#include "shared/cProcedural.fxh"

/*
    [ Shader Options ]
*/

#ifndef ENABLE_BLOOM
    #define ENABLE_BLOOM 1
#endif

#ifndef ENABLE_AUTOEXPOSURE
    #define ENABLE_AUTOEXPOSURE 1
#endif

// Bloom-specific settings
#if ENABLE_BLOOM
    uniform int _RenderMode <
        ui_label = "Bloom";
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

    uniform float _Intensity <
        ui_category = "Bloom";
        ui_label = "Intensity";
        ui_type = "slider";
        ui_step = 0.001;
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
#endif

// Exposure-specific settings
#if ENABLE_AUTOEXPOSURE
    uniform float _Frametime < source = "frametime"; >;

    uniform int _Meter <
        ui_category = "Auto-Exposure";
        ui_label = "Method";
        ui_type = "combo";
        ui_items = "Average\0Spot\0";
    > = 0;

    uniform float _Scale <
        ui_category = "Auto-Exposure";
        ui_label = "Spot Scale";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float2 _Offset <
        ui_category = "Auto-Exposure";
        ui_label = "Spot Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform bool _DisplayAverageLumaOverlay <
        ui_category = "Auto-Exposure";
        ui_label = "Display Average Luminance";
        ui_type = "radio";
    > = false;

    uniform bool _DisplaySpotMeterOverlay <
        ui_category = "Auto-Exposure";
        ui_label = "Display Spot Metering";
        ui_type = "radio";
    > = false;
#endif

#include "shared/cShadeHDR.fxh"
#if ENABLE_AUTOEXPOSURE
    #include "shared/cCameraInput.fxh"
    #include "shared/cCameraOutput.fxh"
#endif
#include "shared/cTonemapOutput.fxh"
#include "shared/cBlend.fxh"

/*
    [ Textures & Samplers ]
*/

// Bloom-specific textures and samplers
#if ENABLE_BLOOM
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

    #if ENABLE_AUTOEXPOSURE
        CREATE_TEXTURE(ExposureTex, int2(1, 1), R16F, 0)
        CREATE_SAMPLER(SampleExposureTex, ExposureTex, LINEAR, CLAMP, CLAMP, CLAMP)
    #endif
// Exposure-specific textures and samplers
#elif ENABLE_AUTOEXPOSURE
    CREATE_TEXTURE(ExposureTex, int2(256, 256), R16F, 9)
    CREATE_SAMPLER(SampleExposureTex, ExposureTex, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

/*
    [ Pixel Shaders ]

    Thresholding | https://github.com/keijiro/Kino [MIT]
    Tonemapping | https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/

// Exposure-specific functions
#if ENABLE_AUTOEXPOSURE
    float2 GetSpotMeterTex(float2 Tex)
    {
        // For spot-metering, we fill the target square texture with the region only
        float2 SpotMeterTex = (Tex * 2.0) - 1.0;

        // Expand the UV so [-1, 1] fills the shape of its input texture instead of output
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            SpotMeterTex.x /= ASPECT_RATIO;
        #else
            SpotMeterTex.y /= ASPECT_RATIO;
        #endif
        SpotMeterTex *= _Scale;
        SpotMeterTex += float2(_Offset.x, -_Offset.y);
        SpotMeterTex = (SpotMeterTex * 0.5) + 0.5;

        return SpotMeterTex;
    }

    void ApplySpotMeterOverlay(inout float3 Color, in float2 UnormTex, in float3 NonExposedColor)
    {
        /*
            Create a UV that represents a square texture.
                Width conversion | [0, 1] -> [-N, N]
                Height conversion | [0, 1] -> [-N, N]
        */
        float2 OverlayPos = UnormTex;
        OverlayPos -= float2(_Offset.x, -_Offset.y);
        OverlayPos /= _Scale;

        // Shrink the UV so [-1, 1] fills a square
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            OverlayPos.x *= ASPECT_RATIO;
        #else
            OverlayPos.y *= ASPECT_RATIO;
        #endif

        // Create the needed mask; output 1 if the texcoord is within square range
        float Factor = 1.0 * _Scale;
        float SquareMask = all(abs(OverlayPos) <= Factor);
        float DotMask = CProcedural_GetAntiAliasShape(length(OverlayPos), Factor * 0.1);

        // Apply square mask to output
        Color = lerp(Color, NonExposedColor.rgb, SquareMask);
        // Apply dot mask to output
        Color = lerp(1.0, Color, DotMask);
    }

    void ApplyAverageLumaOverlay(inout float3 Color, in float2 UnormTex, in Exposure E)
    {
        // The offset goes from [-0.5, 0.5), hence the -0.5 subtraction.
        float2 OverlayPos = UnormTex + float2(0.0, 0.5);

        // Shrink the UV so [-1, 1] fills a square
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            OverlayPos.x *= ASPECT_RATIO;
        #else
            OverlayPos.y *= ASPECT_RATIO;
        #endif

        // Create luma masks
        float OverlayPosLength = length(OverlayPos);
        float OverlayPosMask = CProcedural_GetAntiAliasShape(OverlayPosLength, 0.05);
        float ShadowMask = smoothstep(0.1, 0.0, OverlayPosLength);

        // Create Overlay through alpha compositing
        float4 Overlay = 0.0;
        float4 Shadow = float4(0.0, 0.0, 0.0, 1.0);
        float4 ExpLuma = float4((float3)E.ExpLuma, 1.0);

        // Composite Overlay into Output
        Overlay = lerp(Overlay, Shadow, ShadowMask);
        Overlay = lerp(ExpLuma, Overlay, OverlayPosMask);
        Color = lerp(Color, Overlay.rgb, Overlay.a);
    }

    float4 PS_GetExposure(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        #if ENABLE_BLOOM
            float LogLuminance = tex2D(SampleTempTex8, Input.Tex0).a;
        #else
            float3 Color = CShade_BackBuffer2D(Input.Tex0).rgb;
            float LogLuminance = CCamera_GetLogLuminance(Color);
        #endif

        return CCamera_CreateExposureTex(LogLuminance, _Frametime);
    }
#endif

// Bloom-specific functions
#if ENABLE_BLOOM
    float4 PS_Prefilter(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float4 Color = CShade_BackBuffer2D(Input.Tex0);
        float Luminance = 1.0;

        // Apply auto-exposure to the backbuffer
        #if ENABLE_AUTOEXPOSURE
            // Store log luminance in the alpha channel
            if (_Meter == 1)
            {
                float3 ColorArea = CShade_BackBuffer2D(GetSpotMeterTex(Input.Tex0)).rgb;
                Luminance = CCamera_GetLogLuminance(ColorArea.rgb);
            }
            else
            {
                Luminance = CCamera_GetLogLuminance(Color.rgb);
            }

            // Apply auto-exposure to input
            float Luma = tex2D(SampleExposureTex, Input.Tex0).r;
            Exposure ExposureData = CCamera_GetExposureData(Luma);
            Color = CCamera_ApplyAutoExposure(Color.rgb, ExposureData);
        #endif

        // Thresholding phase
        const float Knee = mad(_Threshold, _Smooth, 1e-5);
        const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);

        // Under-threshold
        float Brightness = CColor_GetLuma(Color.rgb, 3);
        float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
        ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

        // Combine and apply the brightness response curve
        Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);

        return float4(Color.rgb * _ColorShift, Luminance);
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
#endif

float4 PS_Composite(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 BaseColor = CShade_BackBuffer2D(Input.Tex0).rgb;
    float3 NonExposedColor = BaseColor;

    // Apply auto-exposure to base-color
    #if ENABLE_AUTOEXPOSURE
        float Luma = tex2Dlod(SampleExposureTex, float4(Input.Tex0, 0.0, 99.0)).r;
        Exposure ExposureData = CCamera_GetExposureData(Luma);
        BaseColor = CCamera_ApplyAutoExposure(BaseColor.rgb, ExposureData);
    #endif

    // Bloom composition
    #if ENABLE_BLOOM
        float3 BloomColor = tex2D(SampleTempTex1, Input.Tex0).rgb * _Intensity;
        BaseColor = (_RenderMode == 0) ? BaseColor + BloomColor : BloomColor;
    #endif

    // Apply tonemapping
    BaseColor = CTonemap_ApplyOutputTonemap(BaseColor);

    // Apply overlays
    #if ENABLE_AUTOEXPOSURE
        float2 UnormTex = (Input.Tex0 * 2.0) - 1.0;

        if (_DisplaySpotMeterOverlay)
        {
            ApplySpotMeterOverlay(BaseColor, UnormTex, NonExposedColor);
        }

        if (_DisplayAverageLumaOverlay)
        {
            ApplyAverageLumaOverlay(BaseColor, UnormTex, ExposureData);
        }
    #endif

    return CBlend_OutputChannels(float4(BaseColor, _CShadeAlphaFactor));
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


technique CShade_RaySchism < ui_tooltip = "CShade's Color Multi-tool."; >
{
    #if ENABLE_BLOOM
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
    #endif

    pass Composition
    {
        ClearRenderTargets = FALSE;
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Composite;
    }

    /*
        Store the coarsest level of the log luminance pyramid in an accumulation texture.
        We store the coarsest level here to synchronize the auto-exposure Luma texture in the PS_Prefilter and PS_Composite passes.
    */
    #if ENABLE_AUTOEXPOSURE
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