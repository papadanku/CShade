#include "shared/cGraphics.fxh"

/*
    Automatic exposure shader using hardware blending
*/

uniform float _Frametime : FrameTime;
uniform float _SmoothingSpeed : Smoothing;
uniform float _ManualBias : Bias;

uniform texture2D ColorTex: TEXLAYER0;
uniform texture2D LumaTex: TEXLAYER1;

sampler2D SampleColorTex
{
    Texture = ColorTex;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D SampleLumaTex
{
    Texture = LumaTex;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

/*
    Pixel shaders
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

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float3 Luma = max(Color.r, max(Color.g, Color.b));

    // OutputColor0.rgb = Output the highest brightness out of red/green/blue component
    // OutputColor0.a = Output the weight for temporal blending
    float Delay = 1e-3 * _Frametime;
    return float4(Luma, saturate(Delay * _SmoothingSpeed));
}

float3 PS_Exposure(VS2PS_Quad Input) : SV_TARGET0
{
    float AverageLuma = tex2Dlod(SampleLumaTex, float4(Input.Tex0, 0.0, 99.0)).r;
    float4 Color = tex2D(SampleColorTex, Input.Tex0);
    return GetAutoExposure(Color.rgb, AverageLuma);
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
