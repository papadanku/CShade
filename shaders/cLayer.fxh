
#include "shared/cColor.fxh"

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#define CSHADE_APPLY_BLENDING 0
#define CSHADE_APPLY_GRAIN 0
#define CSHADE_APPLY_VIGNETTE 0
#define CSHADE_APPLY_GRADING 0
#define CSHADE_APPLY_TONEMAP 0
#define CSHADE_APPLY_PEAKING 0
#define CSHADE_APPLY_SWIZZLE 0
#define CBLEND_BLENDENABLE FALSE
#define CBLEND_BLENDOP ADD
#define CBLEND_BLENDOPALPHA ADD
#define CBLEND_SRCBLEND ONE
#define CBLEND_SRCBLENDALPHA ONE
#define CBLEND_DESTBLEND ZERO
#define CBLEND_DESTBLENDALPHA ZERO
#include "shared/cShade.fxh"

#if BUFFER_COLOR_BIT_DEPTH == 8
    #define FORMAT RGBA8
#else
    #define FORMAT RGB10A2
#endif

// Output in cCopyBuffer
CSHADE_CREATE_TEXTURE_POOLED(SrcTex, CSHADE_BUFFER_SIZE_0, FORMAT, 1)

// Inputs in cBlendBuffer
CSHADE_CREATE_SAMPLER(SampleSrcTex, SrcTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleDestTex, CShade_ColorTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

struct InstanceSettings
{
    int AlphaType;
    int ColorBlendType;
    int AlphaBlendType;
    float4 SrcFactor;
    float4 DestFactor;
    int SrcTransformOrder;
    float SrcAngle;
    float2 SrcTranslate;
    float2 SrcScale;
    int DestTransformOrder;
    float DestAngle;
    float2 DestTranslate;
    float2 DestScale;
};

void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(CShade_SampleGammaTex, Input.Tex0);
}

void PS_Blend(
    in CShade_VS2PS_Quad Input,
    in InstanceSettings Settings,
    inout float4 Output)
{
    const float Pi2 = CMath_GetPi() * 2.0;

    // Create different texcoords.
    float2 SrcTex = Input.Tex0;
    float2 DestTex = Input.Tex0;

    // Apply transformations.
    CMath_ApplyGeometricTransform(
        SrcTex,
        Settings.SrcTransformOrder,
        Settings.SrcAngle * Pi2,
        Settings.SrcTranslate,
        Settings.SrcScale,
        true
    );

    CMath_ApplyGeometricTransform(
        DestTex,
        Settings.DestTransformOrder,
        Settings.DestAngle * Pi2,
        Settings.DestTranslate,
        Settings.DestScale,
        true
    );

    // Grab our textures.
    #if (CSHADE_READ_SRGB == TRUE)
        float4 Src = tex2D(SampleSrcTex, SrcTex);
        float4 Dest = tex2D(SampleDestTex, DestTex);
        Src = CColor_SRGBtoRGB(Src);
        Dest = CColor_SRGBtoRGB(Dest);
    #else
        float4 Src = tex2D(SampleSrcTex, SrcTex);
        float4 Dest = tex2D(SampleDestTex, DestTex);
    #endif

    // Set our alpha to constant
    if (Settings.AlphaType == 1)
    {
        Src.a = 0.5;
        Dest.a = 0.5;
    }

    // Weight the colors and alphas based on the user input.
    Src *= Settings.SrcFactor;
    Dest *= Settings.DestFactor;

    // Start blending the color and alpha channels.
    float3 ColorBlend = CColor_Blend(Dest, Src, Settings.ColorBlendType);
    float AlphaBlend = CColor_Blend((float4)Dest, (float4)Src, Settings.AlphaBlendType).r;

    Output = float4(ColorBlend, AlphaBlend);

    #if (CSHADE_WRITE_SRGB == TRUE)
        Output = CColor_RGBtoSRGB(Output);
    #endif
}

#define CLAYER_CREATE_SHADER_COPY(index) \
    technique cLayer_CopyLayer##index \
    < \
        ui_label = CSHADE_TO_STRING(CShade | Copy Layer index); \
        ui_tooltip = "Writes the current output into a temporary, RGBA8 texture for blending with a cLayer_BlendLayer shader.\n\n[&] You need to enable and put at least 1 of these shaders above 'CShade / Blend Layer N' for blending to work."; \
    > \
    { \
        pass Copy \
        { \
            VertexShader = CShade_VS_Quad; \
            PixelShader = PS_Copy; \
            RenderTarget0 = SrcTex; \
        } \
    }

#define CLAYER_CREATE_SHADER_BLEND(index) \
    uniform int _AlphaType_##index < \
        ui_category_closed = true; \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_text = "BLENDING SETTINGS"; \
        ui_items = "Existing Alpha\0Constant (0.5)\0"; \
        ui_label = "Alpha Mode"; \
        ui_type = "combo"; \
        ui_tooltip = "Selects which alpha is used for Average blending."; \
    > = 0; \
    \
    uniform int _ColorBlendType_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_items = "None\0Alpha Weighted\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0"; \
        ui_label = "Color Blending Mode"; \
        ui_type = "combo"; \
        ui_tooltip = "Selects the blending mode to combine colors from the source and destination. This affects how colors interact."; \
    > = 0; \
    \
    uniform int _AlphaBlendType_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_items = "None\0Normal\0Multiply\0Screen\0Overlay\0Darken\0Lighten\0Color Dodge\0Color Burn\0Hard Light\0Soft Light\0Difference\0Exclusion\0"; \
        ui_label = "Alpha Blending Mode"; \
        ui_type = "combo"; \
        ui_tooltip = "Selects the blending mode to combine alpha (transparency) values from the source and destination. This affects how transparency interacts."; \
    > = 0; \
    \
    uniform float4 _SrcFactor_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Source RGBA Influence"; \
        ui_type = "drag"; \
        ui_tooltip = "Adjusts the influence of the source RGBA (the RGBA being applied) during blending. Higher values mean more of the source RGBA is used."; \
    > = 1.0; \
    \
    uniform float4 _DestFactor_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Destination RGBA Influence"; \
        ui_type = "drag"; \
        ui_tooltip = "Adjusts the influence of the destination RGBA (the RGBA already present) during blending. Higher values mean more of the existing RGBA is retained."; \
    > = 1.0; \
    \
    uniform int _SrcTransformOrder_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_text = "GEOMETRIC TRANSFORM / SOURCE IMAGE"; \
        ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0"; \
        ui_label = "Transform Order"; \
        ui_type = "combo"; \
        ui_tooltip = "Defines the order in which geometric transformations are applied to the mask."; \
    > = 0; \
    \
    uniform float _SrcAngle_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Rotation Angle"; \
        ui_type = "drag"; \
        ui_tooltip = "Controls the rotation of the mask around its center."; \
    > = 0.0; \
    \
    uniform float2 _SrcTranslate_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Translation"; \
        ui_type = "drag"; \
        ui_tooltip = "Controls the horizontal and vertical translation (position) of the mask."; \
    > = 0.0; \
    \
    uniform float2 _SrcScale_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Scale"; \
        ui_type = "drag"; \
        ui_tooltip = "Controls the horizontal and vertical scaling of the mask."; \
    > = 1.0; \
    \
    uniform int _DestTransformOrder_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_text = "GEOMETRIC TRANSFORM / DESTINATION IMAGE"; \
        ui_items = "Scale > Rotate > Translate\0Scale > Translate > Rotate\0Rotate > Scale > Translate\0Rotate > Translate > Scale\0Translate > Scale > Rotate\0Translate > Rotate > Scale\0"; \
        ui_label = "Transform Order"; \
        ui_type = "combo"; \
        ui_tooltip = "Defines the order in which geometric transformations are applied to the mask."; \
    > = 0; \
    \
    uniform float _DestAngle_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Rotation Angle"; \
        ui_type = "drag"; \
        ui_tooltip = "Controls the rotation of the mask around its center."; \
    > = 0.0; \
    \
    uniform float2 _DestTranslate_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Translation"; \
        ui_type = "drag"; \
        ui_tooltip = "Controls the horizontal and vertical translation (position) of the mask."; \
    > = 0.0; \
    \
    uniform float2 _DestScale_##index < \
        ui_category = CSHADE_TO_STRING(Blend Layer index); \
        ui_label = "Scale"; \
        ui_type = "drag"; \
        ui_tooltip = "Controls the horizontal and vertical scaling of the mask."; \
    > = 1.0; \
    \
    void PS_Blend_##index(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0) \
    { \
        InstanceSettings Settings; \
        Settings.AlphaType = _AlphaType_##index; \
        Settings.ColorBlendType = _ColorBlendType_##index; \
        Settings.AlphaBlendType = _AlphaBlendType_##index; \
        Settings.SrcFactor = _SrcFactor_##index; \
        Settings.DestFactor = _DestFactor_##index; \
        Settings.SrcTransformOrder = _SrcTransformOrder_##index; \
        Settings.SrcAngle = _SrcAngle_##index; \
        Settings.SrcTranslate = _SrcTranslate_##index; \
        Settings.SrcScale = _SrcScale_##index; \
        Settings.DestTransformOrder = _DestTransformOrder_##index; \
        Settings.DestAngle = _DestAngle_##index; \
        Settings.DestTranslate = _DestTranslate_##index; \
        Settings.DestScale = _DestScale_##index; \
        PS_Blend(Input, Settings, Output); \
    } \
    \
    technique cLayer_BlendLayer##index \
    < \
        ui_label = CSHADE_TO_STRING(CShade | Blend Layer index); \
        ui_tooltip = "Blend with CBlend's copy texture."; \
    > \
    { \
        pass Blend \
        { \
            VertexShader = CShade_VS_Quad; \
            PixelShader = PS_Blend_##index; \
        } \
    }
