#define CSHADE_AUTOEXPOSURE

#include "shared/cColor.fxh"

/*
    [ Shader Options ]
*/

// Exposure-specific settings
uniform float _Frametime < source = "frametime"; >;

#if SHADER_TOGGLE_GRADING

    #include "shared/cShadeHDR.fxh"

    uniform float _GradeLightness <
        ui_category = "Main Shader";
        ui_label = "Overall Brightness";
        ui_text = "Color Adjustments";
        ui_tooltip = "Adjusts the overall brightness or darkness of the image.";
        ui_type = "drag";
    > = 0.0;

    uniform float _GradeSaturation <
        ui_category = "Main Shader";
        ui_label = "Color Intensity";
        ui_max = 1.0;
        ui_min = -1.0;
        ui_type = "slider";
        ui_tooltip = "Controls the intensity of colors in the image. Higher values mean more vibrant colors.";
    > = 0.0;

    uniform float _GradeHueShift <
        ui_category = "Main Shader";
        ui_label = "Color Tint Shift";
        ui_max = 1.0;
        ui_min = -1.0;
        ui_type = "slider";
        ui_tooltip = "Shifts the hue of colors in the image, changing their tint.";
    > = 0.0;

    uniform float _GradeContrast <
        ui_category = "Main Shader";
        ui_label = "Difference between Light and Dark";
        ui_max = 1.0;
        ui_min = -1.0;
        ui_type = "slider";
        ui_tooltip = "Adjusts the difference between the brightest and darkest parts of the image.";
    > = 0.0;

    uniform float3 _GradeColorFilter <
        ui_category = "Main Shader";
        ui_label = "Apply Color Tint";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "color";
        ui_tooltip = "Applies a color tint to the entire image, useful for white balance or creative effects.";
    > = 1.0;

    uniform float _GradeTemperature <
        ui_category = "Main Shader";
        ui_label = "Color Temperature (Warm/Cool)";
        ui_max = 1.0;
        ui_min = -1.0;
        ui_text = "\nWhite Balance";
        ui_type = "slider";
        ui_tooltip = "Adjusts the color temperature of the image, making it warmer (yellow/red) or cooler (blue).";
    > = 0.0;

    uniform float _GradeTint <
        ui_category = "Main Shader";
        ui_label = "Green/Magenta Balance";
        ui_max = 1.0;
        ui_min = -1.0;
        ui_type = "slider";
        ui_tooltip = "Adjusts the green-magenta balance of the image.";
    > = 0.0;

    uniform float3 _GradeShadows <
        ui_category = "Main Shader";
        ui_label = "Shadow Color Tint";
        ui_text = "\nSplit Toning";
        ui_type = "color";
        ui_tooltip = "Applies a color tint to the darker areas of the image.";
    > = float3(0.5, 0.5, 0.5);

    uniform float3 _GradeHighLights <
        ui_category = "Main Shader";
        ui_label = "Highlight Color Tint";
        ui_type = "color";
        ui_tooltip = "Applies a color tint to the brighter areas of the image.";
    > = float3(0.5, 0.5, 0.5);

    uniform float _GradeBalance <
        ui_category = "Main Shader";
        ui_label = "Shadow/Highlight Balance";
        ui_max = 1.0;
        ui_min = -1.0;
        ui_type = "slider";
        ui_tooltip = "Adjusts the balance between shadows and highlights in split toning.";
    > = 0.0;

    uniform float3 _GradeMixRed <
        ui_category = "Main Shader";
        ui_label = "Red Channel Mix";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_text = "\nChannel Mixer";
        ui_type = "color";
        ui_tooltip = "Adjusts the contribution of red, green, and blue channels to the output red channel.";
    > = float3(1.0, 0.0, 0.0);

    uniform float3 _GradeMixGreen <
        ui_category = "Main Shader";
        ui_label = "Green Channel Mix";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "color";
        ui_tooltip = "Adjusts the contribution of red, green, and blue channels to the output green channel.";
    > = float3(0.0, 1.0, 0.0);

    uniform float3 _GradeMixBlue <
        ui_category = "Main Shader";
        ui_label = "Blue Channel Mix";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "color";
        ui_tooltip = "Adjusts the contribution of red, green, and blue channels to the output blue channel.";
    > = float3(0.0, 0.0, 1.0);

    uniform float3 _GradeMidtoneShadowColor <
        ui_category = "Main Shader";
        ui_label = "Shadow Midtone Color Tint";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "color";
        ui_tooltip = "Sets the color tint for the shadow midtones.";
    > = float3(1.0, 1.0, 1.0);

    uniform float3 _GradeMidtoneColor <
        ui_category = "Main Shader";
        ui_label = "Midtone Color Tint";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_text = "\nShadows / Midtones / Hightlights";
        ui_type = "color";
        ui_tooltip = "Sets the color tint for the midtones.";
    > = float3(1.0, 1.0, 1.0);

    uniform float3 _GradeMidtoneHighlightColor <
        ui_category = "Main Shader";
        ui_label = "Highlight Midtone Color Tint";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "color";
        ui_tooltip = "Sets the color tint for the highlight midtones.";
    > = float3(1.0, 1.0, 1.0);

    uniform float _GradeMidtoneShadowStart <
        ui_category = "Main Shader";
        ui_label = "Shadow Region Start";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
        ui_tooltip = "Defines the starting point of the shadow region for midtone adjustments.";
    > = 0.0;

    uniform float _GradeMidtoneShadowEnd <
        ui_category = "Main Shader";
        ui_label = "Shadow Region End";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
        ui_tooltip = "Defines the ending point of the shadow region for midtone adjustments.";
    > = 0.3;

    uniform float _GradeMidtoneHighlightStart <
        ui_category = "Main Shader";
        ui_label = "Highlight Region Start";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
    > = 0.55;

    uniform float _GradeMidtoneHighlightEnd <
        ui_category = "Main Shader";
        ui_label = "Highlight Region End";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
        ui_tooltip = "Defines the ending point of the highlight region for midtone adjustments.";
    > = 1.0;

    #include "shared/cCamera.fxh"

#else
    #include "shared/cShadeHDR.fxh"
    #include "shared/cCamera.fxh"
#endif

#include "shared/cComposite.fxh"
#include "shared/cBlend.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nCCOMPOSITE_TOGGLE_GRADING - Enables color grading.\n\n\tOptions: 0 (disabled), 1 (enabled)\n\n";
    ui_type = "radio";
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


void PS_GetExposure(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float2 Tex = (_CCamera_MeteringType == 1) ? CCamera_GetSpotMeterTex(Input.Tex0) : Input.Tex0;
    float3 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Tex).rgb;
    float LogLuminance = CCamera_GetLogLuminance(Color);
    Output = CCamera_CreateExposureTex(LogLuminance, _Frametime);
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 BaseColor = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 NonExposedColor = BaseColor;

    // Apply auto exposure to base-color
    float Luma = tex2Dlod(SampleExposureTex, float4(Input.Tex0, 0.0, 99.0)).r;
    Exposure ExposureData = CCamera_GetExposureData(Luma);
    BaseColor = CCamera_ApplyAutoExposure(BaseColor.rgb, ExposureData);

    // Store the exposed color here for checkerboard check
    float3 ExposedColor = BaseColor;
    CComposite_ApplyOutput(BaseColor.rgb);

    // Apply overlays
    float2 UnormTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
    CCAmera_ApplyExposurePeaking(BaseColor, Input.HPos.xy);
    CCamera_ApplySpotMeterOverlay(BaseColor, UnormTex, NonExposedColor);
    CCamera_ApplyAverageLumaOverlay(BaseColor, UnormTex, ExposureData);

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
        PixelShader = PS_Main;
    }
}
