
/*
    [Shader Options]
*/

uniform float _BlendFactor <
    ui_label = "Frame Blending";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE(BlendTex, BUFFER_SIZE_0, RGBA8, 1)
CREATE_SRGB_SAMPLER(SampleBlendTex, BlendTex, 1, CLAMP)

/*
    [Pixel Shaders]
*/

float4 PS_Blend(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    // Copy backbuffer to a that continuously blends with its previous result 
    return float4(tex2D(CShade_SampleColorTex, Input.Tex0).rgb, _BlendFactor);
}

float4 PS_Display(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    // Display the buffer
    return float4(tex2D(SampleBlendTex, Input.Tex0).rgb, _CShadeAlphaFactor);
}

technique CShade_FrameBlend
{
    pass
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Blend;
        RenderTarget0 = BlendTex;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Display;
    }
}
