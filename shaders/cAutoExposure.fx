#define CSHADE_AUTOEXPOSURE

#include "shared/cColor.fxh"
#include "shared/cProcedural.fxh"

/*
    [ Shader Options ]
*/

#ifndef ENABLE_GRADING
    #define ENABLE_GRADING 0
#endif

// Exposure-specific settings
uniform float _Frametime < source = "frametime"; >;

uniform int _ExposureMeter <
    ui_category = "Exposure";
    ui_label = "Adaptation";
    ui_type = "combo";
    ui_items = "Average Metering\0Spot Metering\0";
> = 0;

uniform float _AverageExposureScale <
    ui_category = "Exposure · Luminance Meter";
    ui_label = "Scale";
    ui_type = "slider";
    ui_min = 1e-3;
    ui_max = 1.0;
> = 0.75;

uniform float2 _AverageExposureOffset <
    ui_category = "Exposure · Luminance Meter";
    ui_label = "Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = float2(0.0, -0.25);

uniform bool _ExposureLumaOverlay <
    ui_category = "Exposure · Luminance Meter";
    ui_label = "Enable Luminance Meter";
    ui_type = "radio";
> = false;

uniform float _SpotExposureScale <
    ui_category = "Exposure · Spot Meter";
    ui_label = "Scale";
    ui_type = "slider";
    ui_min = 1e-3;
    ui_max = 1.0;
> = 0.5;

uniform float2 _SpotExposureOffset <
    ui_category = "Exposure · Spot Meter";
    ui_label = "Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = 0.0;

uniform bool _ExposureSpotMeterOverlay <
    ui_category = "Exposure · Spot Meter";
    ui_label = "Show Area";
    ui_type = "radio";
> = false;

#if ENABLE_GRADING
    uniform float _GradeLightness <
        ui_category = "Color Grading · Color Adjustments";
        ui_label = "Lightness";
        ui_type = "drag";
    > = 0.0;

    uniform float _GradeSaturation <
        ui_category = "Color Grading · Color Adjustments";
        ui_label = "Saturation";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float _GradeHueShift <
        ui_category = "Color Grading · Color Adjustments";
        ui_label = "Hue";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float _GradeContrast <
        ui_category = "Color Grading · Color Adjustments";
        ui_label = "Contrast";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float3 _GradeColorFilter <
        ui_category = "Color Grading · Color Adjustments";
        ui_label = "Color Filter";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 1.0;

    uniform float _GradeTemperature <
        ui_category = "Color Grading · White Balance";
        ui_label = "Temperature";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float _GradeTint <
        ui_category = "Color Grading · White Balance";
        ui_label = "Tint";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float3 _GradeShadows <
        ui_category = "Color Grading · Split Toning";
        ui_label = "Shadows";
        ui_type = "color";
    > = float3(0.5, 0.5, 0.5);

    uniform float3 _GradeHighLights <
        ui_category = "Color Grading · Split Toning";
        ui_label = "Highlights";
        ui_type = "color";
    > = float3(0.5, 0.5, 0.5);

    uniform float _GradeBalance <
        ui_category = "Color Grading · Split Toning";
        ui_label = "Balance";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float3 _GradeMixRed <
        ui_category = "Color Grading · Channel Mixer";
        ui_label = "Red";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(1.0, 0.0, 0.0);

    uniform float3 _GradeMixGreen <
        ui_category = "Color Grading · Channel Mixer";
        ui_label = "Green";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(0.0, 1.0, 0.0);

    uniform float3 _GradeMixBlue <
        ui_category = "Color Grading · Channel Mixer";
        ui_label = "Blue";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(0.0, 0.0, 1.0);

    uniform float3 _GradeMidtoneShadowColor <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Shadow Color";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(1.0, 1.0, 1.0);

    uniform float3 _GradeMidtoneColor <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Midtone Color";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(1.0, 1.0, 1.0);

    uniform float3 _GradeMidtoneHighlightColor <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Highlight Color";
        ui_type = "color";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(1.0, 1.0, 1.0);

    uniform float _GradeMidtoneShadowStart <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Shadows Start";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float _GradeMidtoneShadowEnd <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Shadows End";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.3;

    uniform float _GradeMidtoneHighlightStart <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Highlights Start";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.55;

    uniform float _GradeMidtoneHighlightEnd <
        ui_category = "Color Grading · Shadows, Midtones, Hightlights";
        ui_label = "Highlights End";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 1.0;
#endif

#include "shared/cShadeHDR.fxh"
#include "shared/cCamera.fxh"
#include "shared/cTonemapOutput.fxh"
#include "shared/cBlend.fxh"

/*
    [ Textures & Samplers ]
*/

CREATE_TEXTURE(ExposureTex, int2(256, 256), R16F, 9)
CREATE_SAMPLER(SampleExposureTex, ExposureTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [ Pixel Shaders ]

    Thresholding | https://github.com/keijiro/Kino [MIT]
    Tonemapping | https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/

// Exposure-specific functions
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

    SpotMeterTex *= _SpotExposureScale;
    SpotMeterTex += float2(_SpotExposureOffset.x, -_SpotExposureOffset.y);
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
    OverlayPos -= float2(_SpotExposureOffset.x, -_SpotExposureOffset.y);
    OverlayPos /= _SpotExposureScale;
    float2 DotPos = OverlayPos;

    // Shrink the UV so [-1, 1] fills a square
    #if BUFFER_WIDTH > BUFFER_HEIGHT
        OverlayPos.x *= ASPECT_RATIO;
    #else
        OverlayPos.y *= ASPECT_RATIO;
    #endif

    // Create the needed mask; output 1 if the texcoord is within square range
    float SquareMask = all(abs(OverlayPos) <= 1.0);

    // Shrink the UV so [-1, 1] fills a square
    #if BUFFER_WIDTH > BUFFER_HEIGHT
        DotPos.x *= ASPECT_RATIO;
    #else
        DotPos.y *= ASPECT_RATIO;
    #endif
    float DotMask = CProcedural_GetAntiAliasShape(length(DotPos), 0.1);

    // Apply square mask to output
    Color = lerp(Color, NonExposedColor.rgb, SquareMask);
    // Apply dot mask to output
    Color = lerp(1.0, Color, DotMask);
}

float4 PS_GetExposure(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = (_ExposureMeter == 1) ? GetSpotMeterTex(Input.Tex0) : Input.Tex0;
    float3 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Tex).rgb;
    float LogLuminance = CCamera_GetLogLuminance(Color);
    return CCamera_CreateExposureTex(LogLuminance, _Frametime);
}

float4 PS_Composite(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 BaseColor = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 NonExposedColor = BaseColor;

    // Apply auto exposure to base-color
    float Luma = tex2Dlod(SampleExposureTex, float4(Input.Tex0, 0.0, 99.0)).r;
    Exposure ExposureData = CCamera_GetExposureData(Luma);
    BaseColor = CCamera_ApplyAutoExposure(BaseColor.rgb, ExposureData);

    #if ENABLE_GRADING
        // Apply color-grading
        CColor_ApplyColorGrading(
            BaseColor,
            _GradeLightness,
            _GradeHueShift,
            _GradeSaturation,
            _GradeContrast,
            _GradeColorFilter,
            _GradeTemperature,
            _GradeTint,
            _GradeShadows,
            _GradeHighLights,
            _GradeBalance,
            _GradeMixRed,
            _GradeMixGreen,
            _GradeMixBlue,
            _GradeMidtoneShadowColor,
            _GradeMidtoneColor,
            _GradeMidtoneHighlightColor,
            _GradeMidtoneShadowStart,
            _GradeMidtoneShadowEnd,
            _GradeMidtoneHighlightStart,
            _GradeMidtoneHighlightEnd
        );
    #endif

    // Apply tonemapping
    BaseColor = CTonemap_ApplyOutputTonemap(BaseColor);

    // Apply overlays
    float2 UnormTex = (Input.Tex0 * 2.0) - 1.0;

    if ((_ExposureMeter == 1) && _ExposureSpotMeterOverlay)
    {
        ApplySpotMeterOverlay(BaseColor, UnormTex, NonExposedColor);
    }

    if (_ExposureLumaOverlay)
    {
        CCamera_ApplyAverageLumaOverlay(BaseColor, UnormTex, ExposureData, _AverageExposureOffset);
    }

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

technique CShade_AutoExposure
<
    ui_label = "CShade · Auto Exposure";
    ui_tooltip = "Adjustable, lightweight auto exposure with optional color-grading.";
>
{
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

    pass Composition
    {
        ClearRenderTargets = FALSE;
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Composite;
    }
}
