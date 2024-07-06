
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

uniform float _Scale <
    ui_category = "Main Shader: Metering";
    ui_label = "Area Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float2 _Offset <
    ui_category = "Main Shader: Metering";
    ui_label = "Area Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = 0.0;

uniform int _Meter <
    ui_category = "Main Shader: Metering";
    ui_label = "Method";
    ui_type = "combo";
    ui_items = "Average\0Spot\0";
> = 0;

uniform bool _Debug <
    ui_category = "Main Shader: Metering";
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

    if (_Meter == 1)
    {
        Tex = (Tex * 2.0) - 1.0;
        Tex.x /= ASPECT_RATIO;
        Tex = (Tex * _Scale) + float2(_Offset.x, -_Offset.y);
        Tex = (Tex * 0.5) + 0.5;
    }

    float4 Color = tex2D(CShade_SampleColorTex, Tex);
    float LogLuminance = GetLogLuminance(Color.rgb);
    return CreateExposureTex(LogLuminance, _Frametime);
}

float3 PS_Exposure(VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float Luma = tex2Dlod(SampleLumaTex, float4(Input.Tex0, 0.0, 99.0)).r;
    float3 ExposedColor = ApplyAutoExposure(Color.rgb, Luma);

    if (_Debug)
    {
        // Unpack screen coordinates
        float2 Pos = (Input.Tex0 * 2.0) - 1.0;
        Pos = (Pos - float2(_Offset.x, -_Offset.y)) * BUFFER_SIZE_0;
        float Factor = BUFFER_SIZE_0.y * _Scale;

        // Create the needed mask
        bool Dot = all(step(abs(Pos), Factor * 0.1));
        bool Mask = all(step(abs(Pos), Factor));

        // Composite the exposed color with debug overlay
        float3 Color1 = ExposedColor.rgb;
        float3 Color2 = lerp(Dot * 2.0, Color.rgb, Mask * 0.5);

        return lerp(ApplyOutputTonemap(Color1), Color2, Mask).rgb;
    }
    else
    {
        return ApplyOutputTonemap(ExposedColor);
    }
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
