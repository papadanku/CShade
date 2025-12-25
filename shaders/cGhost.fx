#define CSHADE_GHOSTING

/*
    [Shader Options]
*/

#if BUFFER_COLOR_BIT_DEPTH == 8
    #define FORMAT RGBA8
#else
    #define FORMAT RGB10A2
#endif

uniform float _BlendFactor <
    ui_category = "Main Shader";
    ui_label = "Ghosting Temporal Smoothing";
    ui_max = 0.9;
    ui_min = 0.1;
    ui_type = "slider";
    ui_tooltip = "Controls the strength of the temporal smoothing, determining how much of the previous frame is blended with the current frame to create the ghosting effect.";
> = 0.5;

#include "shared/cColor.fxh"
#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures & Samplers]
*/

CSHADE_CREATE_TEXTURE(PreviousFrame, CSHADE_BUFFER_SIZE_0, FORMAT, 1)
CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex, PreviousFrame, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
*/

// Display the buffer
void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 CurrentFrame = tex2D(CShade_SampleColorTex, Input.Tex0);
    float4 PreviousFrame = CColor_SRGBtoRGB(tex2D(SamplePreviousFrameTex, Input.Tex0));
    float3 BlendColor = lerp(CurrentFrame.rgb, PreviousFrame.rgb, _BlendFactor);

    Output = CBlend_OutputChannels(BlendColor, _CShade_AlphaFactor);
}

// Copy backbuffer to a that continuously blends with its previous result
void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(CShade_SampleColorTex, Input.Tex0);
}

technique CShade_Ghosting
<
    ui_label = "CShade / Ghosting";
    ui_tooltip = "A ghosting effect through frame-blending.";
>
{
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }

    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = PreviousFrame;
    }
}
