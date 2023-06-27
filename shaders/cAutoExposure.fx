#include "shared/cMacros.fxh"
#include "shared/cGraphics.fxh"

/*
    Automatic exposure shader using hardware blending
*/

/*
    [Shader Options]
*/

uniform float _Frametime < source = "frametime"; >;

uniform float _SmoothingSpeed <
    ui_category = "Exposure";
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_tooltip = "Exposure time smoothing";
    ui_min = 0.0;
    ui_max = 10.0;
> = 2.0;

uniform float _ManualBias <
    ui_category = "Exposure";
    ui_label = "Exposure";
    ui_type = "drag";
    ui_tooltip = "Optional manual bias ";
    ui_min = 0.0;
> = 2.0;

uniform float _Scale <
    ui_category = "Spot Metering";
    ui_label = "Area Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float2 _Offset <
    ui_category = "Spot Metering";
    ui_label = "Area Offset";
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
> = 0.0;

uniform int _Meter <
    ui_category = "Spot Metering";
    ui_label = "Method";
    ui_type = "combo";
    ui_items = " Average\0 Centered\0";
> = 0;

uniform bool _Debug <
    ui_category = "Spot Metering";
    ui_label = "Display Center Metering";
    ui_type = "radio";
> = false;

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE(LumaTex, int2(256, 256), R16F, 9)
CREATE_SAMPLER(SampleLumaTex, LumaTex, LINEAR, CLAMP)

/*
    [Pixel Shaders]
    ---
    TODO: Add average, spot, and center-weighted metering with adjustable radius and slope
    ---
    AutoExposure(): https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
*/

float3 GetAutoExposure(float3 Color, float Average)
{
    // NOTE: KeyValue is an exposure compensation curve
    float KeyValue = 1.03 - (2.0 / (log10(Average + 1.0) + 2.0));
    float ExposureValue = log2(KeyValue / Average) + _ManualBias;
    return Color * exp2(ExposureValue);
}

float2 Expand(float2 X)
{
    return (X * 2.0) - 1.0;
}

float2 Contract(float2 X)
{
    return (X * 0.5) + 0.5;
}

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex = Input.Tex0;

    if (_Meter == 1)
    {
        Tex = Expand(Tex);
        Tex.x /= ASPECT_RATIO;
        Tex = (Tex * _Scale) + float2(_Offset.x, -_Offset.y);
        Tex = Contract(Tex);
    }

    float4 Color = tex2D(CShade_SampleColorTex, Tex);
    float3 Luma = max(Color.r, max(Color.g, Color.b));

    // OutputColor0.rgb = Output the highest brightness out of red/green/blue component
    // OutputColor0.a = Output the weight for temporal blending
    float Delay = 1e-3 * _Frametime;
    return float4(Color.rgb, saturate(Delay * _SmoothingSpeed));
}

float3 PS_Exposure(VS2PS_Quad Input) : SV_TARGET0
{
    float AverageLuma = tex2Dlod(SampleLumaTex, float4(Input.Tex0, 0.0, 99.0)).r;
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float3 ExposedColor = GetAutoExposure(Color.rgb, AverageLuma);

    if (_Debug)
    {
        // Unpack screen coordinates
        float2 Pos = (Expand(Input.Tex0) - float2(_Offset.x, -_Offset.y)) * BUFFER_SIZE_0;
        float Factor = BUFFER_SIZE_0.y * _Scale;

        // Create the needed mask
        bool Dot = all(step(abs(Pos), Factor * 0.1));
        bool Mask = all(step(abs(Pos), Factor));

        // Composite the exposed color with debug overlay
        float3 Color1 = ExposedColor.rgb;
        float3 Color2 = lerp(Dot * 2.0, Color.rgb, Mask * 0.5);

        return lerp(Color1, Color2, Mask).rgb;
    }
    else
    {
        return ExposedColor;
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
