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
    ui_label = "Blend Weight";
    ui_type = "slider";
    ui_min = 0.1;
    ui_max = 0.9;
> = 0.5;

#include "shared/cColor.fxh"
#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE(PreviousFrame, BUFFER_SIZE_0, FORMAT, 1)
CREATE_SAMPLER(SamplePreviousFrame, PreviousFrame, 1, CLAMP, CLAMP, CLAMP)

/*
    [Pixel Shaders]
*/

// Display the buffer
float4 PS_Blend(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 CurrentFrame = tex2D(CShade_SampleColorTex, Input.Tex0);
    float4 PreviousFrame = CColor_SRGBToLinear(tex2D(SamplePreviousFrame, Input.Tex0));
    float3 BlendColor = lerp(CurrentFrame.rgb, PreviousFrame.rgb, _BlendFactor);

    return CBlend_OutputChannels(float4(BlendColor, _CShadeAlphaFactor));
}

// Copy backbuffer to a that continuously blends with its previous result
float4 PS_Copy(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return tex2D(CShade_SampleColorTex, Input.Tex0);
}

technique CShade_Ghosting < ui_tooltip = "A ghosting effect through frame-blending"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blend;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = PreviousFrame;
    }
}
