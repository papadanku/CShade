#define CSHADE_AUTOEXPOSURE

#include "shared/cColor.fxh"

/*
    [ Shader Options ]
*/

#ifndef SHADER_TOGGLE_GRADING
    #define SHADER_TOGGLE_GRADING 0
#endif

// Exposure-specific settings
uniform float _Frametime < source = "frametime"; >;

#if SHADER_TOGGLE_GRADING

    #include "shared/cShadeHDR.fxh"

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

    #include "shared/cCamera.fxh"

#else
    #include "shared/cShadeHDR.fxh"
    #include "shared/cCamera.fxh"
#endif

#include "shared/cTonemapOutput.fxh"
#include "shared/cBlend.fxh"

#include "shared/cPreprocessorGuide.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide · Shader";
    ui_label = " ";
    ui_type = "radio";
    ui_text = "\nSHADER_TOGGLE_GRADING - Enables color grading.\n\n\tOptions: 0 (disabled), 1 (enabled)\n\n";
    ui_category_closed = false;
> = 0;

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


float4 PS_GetExposure(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = (_CCameraMeteringType == 1) ? CCamera_GetSpotMeterTex(Input.Tex0) : Input.Tex0;
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

    // Store the exposed color here for checkerboard check
    float3 ExposedColor = BaseColor;

    #if SHADER_TOGGLE_GRADING
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
    float2 UnormTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
    CCAmera_ApplyExposurePeaking(BaseColor, Input.HPos.xy);
    CCamera_ApplySpotMeterOverlay(BaseColor, UnormTex, NonExposedColor);
    CCamera_ApplyAverageLumaOverlay(BaseColor, UnormTex, ExposureData);

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
