#include "shared/cGraphics.fxh"

/*
    Automatic exposure shader using hardware blending
*/

uniform float _TimeRate <
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_tooltip = "Exposure time smoothing";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.95;

uniform float _ManualBias <
    ui_label = "Exposure";
    ui_type = "drag";
    ui_tooltip = "Optional manual bias ";
    ui_min = 0.0;
> = 2.0;

CREATE_TEXTURE(LumaTex, BUFFER_SIZE_1, 9, R16F)
CREATE_SAMPLER(SampleLumaTex, LumaTex, LINEAR, CLAMP)

/*
    Pixel shaders
    ---
    TODO: Add average, spot, and center-weighted metering with adjustable radius and slope
    ---
    AutoExposure(): https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
*/

float3 AutoExposure(float3 Color, float Average)
{
    // NOTE: KeyValue is an exposure compensation curve
    float KeyValue = 1.03 - (2.0 / (log10(Average + 1.0) + 2.0));
    float ExposureValue = log2(KeyValue / Average) + _ManualBias;
    return Color * exp2(ExposureValue);
}

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);

    // OutputColor0.rgb = Output the highest brightness out of red/green/blue component
    // OutputColor0.a = Output the weight for temporal blending
    return float4(max(Color.r, max(Color.g, Color.b)).rrr, _TimeRate);
}

float3 PS_Exposure(VS2PS_Quad Input) : SV_TARGET0
{
    float AverageLuma = tex2Dlod(SampleLumaTex, float4(0.5, 0.5, 0.0, 9.0)).r;
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    return AutoExposure(Color.rgb, AverageLuma);
}

technique CShade_AutoExposure
{
    pass
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;

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
