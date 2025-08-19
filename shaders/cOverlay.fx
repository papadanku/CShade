#define CSHADE_OVERLAY

/*
    [Shader Options]
*/

#ifndef SHADER_BACKBUFFER_SAMPLING
    #define SHADER_BACKBUFFER_SAMPLING POINT
#endif

uniform float2 _TexScale <
    ui_label = "Image Scale";
    ui_type = "drag";
    ui_step = 0.001;
> = float2(0.5, 0.5);

uniform float2 _TexOffset <
    ui_label = "Image Offset";
    ui_type = "drag";
    ui_step = 0.001;
> = float2(0.0, 0.0);

uniform float2 _MaskScale <
    ui_label = "Mask Scale";
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
> = float2(0.5, 0.5);

uniform float2 _MaskOffset <
    ui_label = "Mask Offset";
    ui_type = "drag";
    ui_min = -1.0;
    ui_max = 1.0;
> = float2(0.0, 0.0);

#include "shared/cShadeHDR.fxh"

/*
    [Textures & Samplers]
*/

sampler2D SampleColorTex_Overlay
{
    Texture = CShade_ColorTex;
    MagFilter = SHADER_BACKBUFFER_SAMPLING;
    MinFilter = SHADER_BACKBUFFER_SAMPLING;
    MipFilter = LINEAR;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = READ_SRGB;
};

/*
    [Vertex Shaders]
*/

struct VS2PS
{
    float4 HPos : SV_POSITION;
    float4 Tex0 : TEXCOORD0;
};

VS2PS VS_Overlay(CShade_APP2VS Input)
{
    VS2PS Output;
    Output.Tex0.x = (Input.ID == 2) ? 2.0 : 0.0;
    Output.Tex0.y = (Input.ID == 1) ? 2.0 : 0.0;
    Output.HPos = float4(Output.Tex0.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // Scale texture coordinates from [0, 1] to [-1, 1] range
    Output.Tex0.zw = (Output.Tex0.xy * 2.0) - 1.0;
    // Scale and offset in [-1, 1] range
    Output.Tex0.zw = (Output.Tex0.zw * _TexScale) + _TexOffset;
    // Scale texture coordinates from [-1, 1] to [0, 1] range
    Output.Tex0.zw = (Output.Tex0.zw * 0.5) + 0.5;

    return Output;
}

/*
    [Pixel Shaders]
*/

float4 PS_Overlay(VS2PS Input) : SV_TARGET0
{
    float4 Color = CShadeHDR_Tex2D_InvTonemap(SampleColorTex_Overlay, Input.Tex0.zw);

    // Output a rectangle
    float2 MaskCoord = (Input.Tex0.xy * 2.0) - 1.0;
    float2 Shaper = step(abs(MaskCoord + _MaskOffset), _MaskScale);
    float Crop = Shaper.x * Shaper.y;

    return float4(Color.rgb, Crop);
}

technique CShade_Overlay
<
    ui_label = "CShade · Overlay";
    ui_tooltip = "Applies a zoomed copy of the backbuffer.\n\n* Preprocessor Definitions *\n\nSHADER_BACKBUFFER_SAMPLING - How the shader samples pixels from the backbuffer texture.\n\n\tOptions: POINT, LINEAR";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        // Blend the rectangle with the backbuffer
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;

        VertexShader = VS_Overlay;
        PixelShader = PS_Overlay;
    }
}
