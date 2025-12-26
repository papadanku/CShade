#define CSHADE_AUTOEXPOSURE

#include "shared/cColor.fxh"

/*
    [ Shader Options ]
*/

// Exposure-specific settings
uniform float _Frametime < source = "frametime"; >;

#include "shared/cShadeHDR.fxh"

#define CCAMERA_TOGGLE_AUTO_EXPOSURE 1
#define CCAMERA_TOGGLE_EXPOSURE_PEAKING 1
#include "shared/cCamera.fxh"

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

CSHADE_CREATE_TEXTURE(ExposureTex, int2(256, 256), R16F, 9)
CSHADE_CREATE_SAMPLER(SampleExposureTex, ExposureTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [ Pixel Shaders ]

    Thresholding | https://github.com/keijiro/Kino [MIT]
    Tonemapping | https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/


void PS_GetExposure(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float2 Tex = (_CCamera_MeteringType == 1) ? CCamera_GetSpotMeterTex(Input.Tex0) : Input.Tex0;
    float3 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex).rgb;
    float LogLuminance = CCamera_GetLogLuminance(Color);
    Output = CCamera_CreateExposureTex(LogLuminance, _Frametime);
    Output = CMath_GetOutOfBounds(Input.Tex0) ? 0.0 : Output;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float3 BaseColor = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0).rgb;
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
    ui_label = "CShade / Auto Exposure [+]";
    ui_tooltip = "Standalone lightweight, adjustable, auto exposure with optional color-grading.\n\n[+] This shader has optional color grading (CCOMPOSITE_TOGGLE_GRADING).";
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
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
