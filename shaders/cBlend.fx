#define CSHADE_BLEND

/*
    [Shader Options]
*/

#include "shared/cColor.fxh"

uniform int _ColorBlend <
    ui_label = "Color Blend Mode";
    ui_type = "combo";
    ui_items = "Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0";
> = 0;

uniform int _AlphaBlend <
    ui_label = "Alpha Blend Mode";
    ui_type = "combo";
    ui_items = "Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0";
> = 0;

uniform float3 _SrcFactor <
    ui_label = "Source Factor (RGB)";
    ui_type = "drag";
> = 1.0;

uniform float3 _DestFactor <
    ui_label = "Destination Factor (RGB)";
    ui_type = "drag";
> = 1.0;

#include "shared/cShadeHDR.fxh"

/*
    [Textures & Samplers]
*/

// Output in cCopyBuffer
CREATE_TEXTURE(SrcTex, BUFFER_SIZE_0, RGBA8, 1)

// Inputs in cBlendBuffer
CREATE_SRGB_SAMPLER(SampleSrcTex, SrcTex, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleDestTex, CShade_ColorTex, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
*/

float4 PS_Copy(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CShade_BackBuffer2D(Input.Tex0);
}

float4 PS_Blend(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 Src = tex2D(SampleSrcTex, Input.Tex0);
    float4 Dest = tex2D(SampleDestTex, Input.Tex0);

    Src.rgb *= _SrcFactor;
    Dest.rgb *= _DestFactor;

    float3 SrcAlpha = Src.a;
    float3 DestAlpha = Dest.a;

    float3 ColorBlend = CColor_Blend(Dest.rgb, Src.rgb, _ColorBlend);
    float AlphaBlend = CColor_Blend(DestAlpha, SrcAlpha, _AlphaBlend).r;

    return float4(ColorBlend, AlphaBlend);
}

technique CShade_CopyBuffer < ui_tooltip = "Create CBlend's copy texture"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = SrcTex;
    }
}

technique CShade_BlendBuffer < ui_tooltip = "Blend with CBlend's copy texture"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blend;
    }
}
