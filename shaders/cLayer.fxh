
#include "shared/cShade.fxh"
#include "shared/cColor.fxh"

#if BUFFER_COLOR_BIT_DEPTH == 8
    #define FORMAT RGBA8
#else
    #define FORMAT RGB10A2
#endif

// Output in cCopyBuffer
CREATE_TEXTURE_POOLED(SrcTex, BUFFER_SIZE_0, FORMAT, 1)

// Inputs in cBlendBuffer
CREATE_SRGB_SAMPLER(SampleSrcTex, SrcTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleDestTex, CShade_ColorTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(CShade_SampleColorTex, Input.Tex0);
}

#define CLAYER_CREATE_SHADER_COPY(index) \
    technique cLayer_CopyLayer##index \
    < \
        ui_tooltip = "Writes the current output into a temporary, RGBA8 texture for blending with a cLayer_BlendLayer shader.\n\n[!] Required for cLayer_BlendLayer shader."; \
    > \
    { \
        pass \
        { \
            SRGBWriteEnable = WRITE_SRGB; \
            \
            VertexShader = CShade_VS_Quad; \
            PixelShader = PS_Copy; \
            RenderTarget0 = SrcTex; \
        } \
    } \

#define CLAYER_CREATE_SHADER_BLEND(index) \
    uniform int _ColorBlend_##index < \
        ui_category = "Main Shader"; \
        ui_items = "Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0"; \
        ui_label = "Color Blending Mode"; \
        ui_type = "combo"; \
        ui_tooltip = "Selects the blending mode to combine colors from the source and destination. This affects how colors interact."; \
    > = 0; \
    \
    uniform int _AlphaBlend_##index < \
        ui_category = "Main Shader"; \
        ui_items = "Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0"; \
        ui_label = "Alpha Blending Mode"; \
        ui_type = "combo"; \
        ui_tooltip = "Selects the blending mode to combine alpha (transparency) values from the source and destination. This affects how transparency interacts."; \
    > = 0; \
    \
    uniform float3 _SrcFactor_##index < \
        ui_category = "Main Shader"; \
        ui_label = "Source Color Influence"; \
        ui_type = "drag"; \
        ui_tooltip = "Adjusts the influence of the source color (the color being applied) during blending. Higher values mean more of the source color is used."; \
    > = 1.0; \
    \
    uniform float3 _DestFactor_##index < \
        ui_category = "Main Shader"; \
        ui_label = "Destination Color Influence"; \
        ui_type = "drag"; \
        ui_tooltip = "Adjusts the influence of the destination color (the color already present) during blending. Higher values mean more of the existing color is retained."; \
    > = 1.0; \
    \
    void PS_Blend_##index(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0) \
    { \
        float4 Src = tex2D(SampleSrcTex, Input.Tex0); \
        float4 Dest = tex2D(SampleDestTex, Input.Tex0); \
        \
        Src.rgb *= _SrcFactor_##index; \
        Dest.rgb *= _DestFactor_##index; \
        \
        float3 SrcAlpha = Src.a; \
        float3 DestAlpha = Dest.a; \
        \
        float3 ColorBlend = CColor_Blend(Dest.rgb, Src.rgb, _ColorBlend_##index); \
        float AlphaBlend = CColor_Blend(DestAlpha, SrcAlpha, _AlphaBlend_##index).r; \
        \
        Output = float4(ColorBlend, AlphaBlend); \
    } \
    \
    technique cLayer_BlendLayer##index \
    < \
        ui_tooltip = "Blend with CBlend's copy texture."; \
    > \
    { \
        pass \
        { \
            SRGBWriteEnable = WRITE_SRGB; \
            \
            VertexShader = CShade_VS_Quad; \
            PixelShader = PS_Blend_##index; \
        } \
    } \
