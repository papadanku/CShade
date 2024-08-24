
/*
    Automatic exposure shader using hardware blending
*/

/*
    [Shader Options]
*/

uniform float _Frametime < source = "frametime"; >;

uniform int _Meter <
    ui_category = "Exposure | Metering";
    ui_label = "Method";
    ui_type = "combo";
    ui_items = "Average\0Spot\0";
> = 0;

uniform float _Scale <
    ui_category = "Exposure | Metering";
    ui_label = "Spot Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float2 _Offset <
    ui_category = "Exposure | Metering";
    ui_label = "Spot Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = 0.0;

uniform bool _DisplayAverageLuma <
    ui_category = "Shader | Debug";
    ui_label = "Display Average Luminance";
    ui_type = "radio";
> = false;

uniform bool _DisplaySpotMeterMask <
    ui_category = "Shader | Debug";
    ui_label = "Display Spot Metering";
    ui_type = "radio";
> = false;

#include "shared/cMacros.fxh"
#include "shared/cProcedural.fxh"

#define INCLUDE_CCAMERA_INPUT
#define INCLUDE_CCAMERA_OUTPUT
#include "shared/cCamera.fxh"

#define INCLUDE_CTONEMAP_OUTPUT
#include "shared/cTonemap.fxh"

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE(LumaTex, int2(256, 256), R16F, 9)
CREATE_SAMPLER(SampleLumaTex, LumaTex, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
*/

float4 PS_Blit(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = Input.Tex0;
    float2 UNormTex = (Input.Tex0 * 2.0) - 1.0;

    /*
        For spot-metering, we fill the target square texture with the region only
    */
    if (_Meter == 1)
    {
        float2 SpotMeterTex = UNormTex;
        // Expand the UV so [-1, 1] fills the shape of its input texture instead of output
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            SpotMeterTex.x /= ASPECT_RATIO;
        #else
            SpotMeterTex.y /= ASPECT_RATIO;
        #endif
        SpotMeterTex *= _Scale;
        SpotMeterTex += float2(_Offset.x, -_Offset.y);
        SpotMeterTex = (SpotMeterTex * 0.5) + 0.5;
        Tex = SpotMeterTex;
    }

    float4 Color = tex2D(CShade_SampleColorTex, Tex);
    float LogLuminance = GetLogLuminance(Color.rgb);

    return CCamera_CreateExposureTex(LogLuminance, _Frametime);
}

float3 PS_Exposure(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    // Get textures
    float Luma = tex2Dlod(SampleLumaTex, float4(Input.Tex0, 0.0, 99.0)).r;
    float4 NonExposedColor = tex2D(CShade_SampleColorTex, Input.Tex0);

    // Get exposure data
    Exposure ExposureData = CCamera_GetExposureData(Luma);
    float3 ExposedColor = CCamera_ApplyAutoExposure(NonExposedColor.rgb, ExposureData);

    float2 UNormPos = (Input.Tex0 * 2.0) - 1.0;
    float3 Output = CTonemap_ApplyOutputTonemap(ExposedColor.rgb);

    if (_Meter == 1 && _DisplaySpotMeterMask)
    {
        /*
            Create a UV that represents a square texture.
            - Width conversion: [0, 1] -> [-N, N]
            - Height conversion: [0, 1] -> [-N, N]
        */

        float2 SpotMeterPos = UNormPos;
        SpotMeterPos -= float2(_Offset.x, -_Offset.y);
        SpotMeterPos /= _Scale;

        // Shrink the UV so [-1, 1] fills a square
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            SpotMeterPos.x *= ASPECT_RATIO;
        #else
            SpotMeterPos.y *= ASPECT_RATIO;
        #endif

        // Create the needed mask, output 1 if the texcood is within square range
        float Factor = 1.0 * _Scale;
        float SquareMask = all(abs(SpotMeterPos) <= Factor);
        float DotMask = CProcedural_GetAntiAliasShape(length(SpotMeterPos), Factor * 0.1);

        // Apply square mask to output
        Output = lerp(Output, NonExposedColor.rgb, SquareMask);
        // Apply dot mask to output
        Output = lerp(1.0, Output, DotMask);
    }

    if (_DisplayAverageLuma)
    {
        // The offset goes from [-0.5, 0.5], hence the -0.5 subtraction.
        float2 LumaTex = UNormPos + float2(0.0, 0.5);

        // Shrink the UV so [-1, 1] fills a square
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            LumaTex.x *= ASPECT_RATIO;
        #else
            LumaTex.y *= ASPECT_RATIO;
        #endif

        // Create luma masks
        float LumaTexLength = length(LumaTex);
        float LumaTexMask = CProcedural_GetAntiAliasShape(LumaTexLength, 0.05);
        float ShadowMask = smoothstep(0.1, 0.0, LumaTexLength);

        // Create LumaIcon through alpha compositing
        float4 LumaIcon = 0.0;
        float4 Shadow = float4(0.0, 0.0, 0.0, 1.0);
        float4 ExpLuma = float4((float3)ExposureData.ExpLuma, 1.0);

        LumaIcon = lerp(LumaIcon, Shadow, ShadowMask);
        LumaIcon = lerp(ExpLuma, LumaIcon, LumaTexMask);

        // Composite LumaIcon into Output
        Output = lerp(Output, LumaIcon.rgb, LumaIcon.a);
    }

    return CBlend_OutputChannels(float4(Output.rgb, _CShadeAlphaFactor));
}

technique CShade_AutoExposure
{
    pass
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = LumaTex;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Exposure;
    }
}
