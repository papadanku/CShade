
#include "shared/cMacros.fxh"
#include "shared/cGraphics.fxh"

#define INCLUDE_CCAMERA_INPUT
#define INCLUDE_CCAMERA_OUTPUT
#include "shared/cCamera.fxh"

#define INCLUDE_CTONEMAP_OUTPUT
#include "shared/cTonemap.fxh"

/*
    Automatic exposure shader using hardware blending
*/

/*
    [Shader Options]
*/

uniform float _Frametime < source = "frametime"; >;

uniform int _Meter <
    ui_category = "Main Shader: Metering";
    ui_label = "Method";
    ui_type = "combo";
    ui_items = "Average\0Spot\0";
> = 0;

uniform float _Scale <
    ui_category = "Main Shader: Metering";
    ui_label = "Spot Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float2 _Offset <
    ui_category = "Main Shader: Metering";
    ui_label = "Spot Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = 0.0;

uniform bool _DisplayAverageLuma <
    ui_category = "Main Shader: Debug";
    ui_label = "Display Average Luminance";
    ui_type = "radio";
> = false;

uniform bool _DisplaySpotMeterMask <
    ui_category = "Main Shader: Debug";
    ui_label = "Display Spot Metering";
    ui_type = "radio";
> = false;

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE(LumaTex, int2(256, 256), R16F, 9)
CREATE_SAMPLER(SampleLumaTex, LumaTex, LINEAR, CLAMP)

/*
    [Pixel Shaders]
*/

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = Input.Tex0;

    /*
        For spot-metering, we fill the target square texture with the region only
    */
    if (_Meter == 1)
    {
        Tex = (Tex * 2.0) - 1.0;
        // Expand the UV so [-1, 1] fills the shape of its input texture instead of output
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            Tex.x /= ASPECT_RATIO;
        #else
            Tex.y /= ASPECT_RATIO;
        #endif
        Tex *= _Scale;
        Tex += float2(_Offset.x, -_Offset.y);
        Tex = (Tex * 0.5) + 0.5;
    }

    float4 Color = tex2D(CShade_SampleColorTex, Tex);
    float LogLuminance = GetLogLuminance(Color.rgb);
    return CreateExposureTex(LogLuminance, _Frametime);
}

float3 PS_Exposure(VS2PS_Quad Input) : SV_TARGET0
{
    float Luma = tex2Dlod(SampleLumaTex, float4(Input.Tex0, 0.0, 99.0)).r;
    float4 NonExposedColor = tex2D(CShade_SampleColorTex, Input.Tex0);
    float3 ExposedColor = ApplyAutoExposure(NonExposedColor.rgb, Luma);

    float2 UNormPos = (Input.Tex0 * 2.0) - 1.0;
    float3 Output = ApplyOutputTonemap(ExposedColor.rgb);

    if (_DisplaySpotMeterMask)
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
        bool SquareMask = all(abs(SpotMeterPos) <= Factor);
        bool DotMask = all(abs(SpotMeterPos) <= (Factor * 0.1));

        // Apply square mask to output
        Output = lerp(Output, NonExposedColor.rgb, SquareMask);
        // Apply dot mask to output
        Output = lerp(Output, 1.0, DotMask);
    }

    if (_DisplayAverageLuma)
    {
        float2 DebugAverageLumaTex = UNormPos + float2(0.0, -0.5);

        // Shrink the UV so [-1, 1] fills a square
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            DebugAverageLumaTex.x *= ASPECT_RATIO;
        #else
            DebugAverageLumaTex.y *= ASPECT_RATIO;
        #endif

        // This mask returns 1 if the texcoord's position is >= 0.1
        float Mask = 1.0 - saturate(dot(abs(DebugAverageLumaTex) >= 0.05, 1.0));
        Output = lerp(Output, exp(Luma), Mask);
    }

    return Output;
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

        VertexShader = VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = LumaTex;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Exposure;
    }
}
