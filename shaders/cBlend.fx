#define CSHADE_BLEND

/*
    [Shader Options]
*/

#include "shared/cColor.fxh"

uniform int _ColorBlend <
    ui_category = "Main Shader";
    ui_items = "Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0";
    ui_label = "Color Blending Mode";
    ui_type = "combo";
    ui_tooltip = "Selects the blending mode to combine colors from the source and destination. This affects how colors interact.";
> = 0;

uniform int _AlphaBlend <
    ui_category = "Main Shader";
    ui_items = "Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0";
    ui_label = "Alpha Blending Mode";
    ui_type = "combo";
    ui_tooltip = "Selects the blending mode to combine alpha (transparency) values from the source and destination. This affects how transparency interacts.";
> = 0;

uniform float3 _SrcFactor <
    ui_category = "Main Shader";
    ui_label = "Source Color Influence";
    ui_type = "drag";
    ui_tooltip = "Adjusts the influence of the source color (the color being applied) during blending. Higher values mean more of the source color is used.";
> = 1.0;

uniform float3 _DestFactor <
    ui_category = "Main Shader";
    ui_label = "Destination Color Influence";
    ui_type = "drag";
    ui_tooltip = "Adjusts the influence of the destination color (the color already present) during blending. Higher values mean more of the existing color is retained.";
> = 1.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures & Samplers]
*/

// Output in cCopyBuffer
CREATE_TEXTURE(SrcTex, BUFFER_SIZE_0, RGBA8, 1)

// Inputs in cBlendBuffer
CREATE_SRGB_SAMPLER(SampleSrcTex, SrcTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleDestTex, CShade_ColorTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
*/

void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0);
}

void PS_Blend(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Src = tex2D(SampleSrcTex, Input.Tex0);
    float4 Dest = tex2D(SampleDestTex, Input.Tex0);

    Src.rgb *= _SrcFactor;
    Dest.rgb *= _DestFactor;

    float3 SrcAlpha = Src.a;
    float3 DestAlpha = Dest.a;

    float3 ColorBlend = CColor_Blend(Dest.rgb, Src.rgb, _ColorBlend);
    float AlphaBlend = CColor_Blend(DestAlpha, SrcAlpha, _AlphaBlend).r;

    Output = CBlend_OutputChannels(ColorBlend, AlphaBlend);
}

technique CShade_CopyBuffer
<
    ui_label = "CShade · Copy Buffer";
    ui_tooltip = "Create CBlend's copy texture.";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = SrcTex;
    }
}

technique CShade_BlendBuffer
<
    ui_label = "CShade · Blend Buffer";
    ui_tooltip = "Blend with CBlend's copy texture.";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blend;
    }
}
