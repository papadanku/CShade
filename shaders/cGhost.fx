#define CSHADE_GHOSTING

/*
    This shader creates a ghosting effect by blending the current frame with a temporally smoothed previous frame. This produces a trailing visual artifact, simulating motion blur or an ethereal appearance. Users can adjust the blend factor to control the intensity of the ghosting effect.
*/

/* Shader Options */

#if BUFFER_COLOR_BIT_DEPTH == 8
    #define FORMAT RGBA8
#else
    #define FORMAT RGB10A2
#endif

#include "shared/cColor.fxh"

uniform float _BlendFactor <
    ui_label = "Ghosting Temporal Smoothing";
    ui_max = 0.9;
    ui_min = 0.1;
    ui_type = "slider";
    ui_tooltip = "Controls the strength of the temporal smoothing, determining how much of the previous frame is blended with the current frame to create the ghosting effect.";
> = 0.5;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/* Textures & Samplers */

CSHADE_CREATE_TEXTURE(PreviousFrame, CSHADE_BUFFER_SIZE_0, FORMAT, 1)
CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex, PreviousFrame, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

/* Pixel Shaders */

// Display the buffer
void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    #if (CSHADE_WRITE_SRGB == TRUE)
        float4 CurrentFrame = tex2D(CShade_SampleGammaTex, Input.Tex0);
        float4 PreviousFrame = tex2D(SamplePreviousFrameTex, Input.Tex0);
        CurrentFrame = CColor_SRGBtoRGB(CurrentFrame);
        PreviousFrame = CColor_SRGBtoRGB(PreviousFrame);
    #else
        float4 CurrentFrame = tex2D(CShade_SampleGammaTex, Input.Tex0);
        float4 PreviousFrame = tex2D(SamplePreviousFrameTex, Input.Tex0);
    #endif

    float3 BlendColor = lerp(CurrentFrame.rgb, PreviousFrame.rgb, _BlendFactor);

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(BlendColor, _CShade_AlphaFactor);
    #else
        Output = float4(BlendColor, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);

    #if (CSHADE_WRITE_SRGB == TRUE)
        Output = CColor_RGBtoSRGB(Output);
    #endif
}

// Copy backbuffer to a that continuously blends with its previous result
void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(CShade_SampleGammaTex, Input.Tex0);
}

technique CShade_Ghosting
<
    ui_label = "CShade | Ghosting";
    ui_tooltip = "A ghosting effect through frame-blending.";
>
{
    pass Ghosting
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }

    pass CopyFrame
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = PreviousFrame;
    }
}
