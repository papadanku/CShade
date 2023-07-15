
#include "shared/cGraphics.fxh"
#include "shared/cBuffers.fxh"

CREATE_SAMPLER(SampleTempTex0, TempTex0_RGB10A2, POINT, CLAMP)

float4 PS_Blit(VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(CShade_SampleColorTex, Input.Tex0).rgb, 1.0);
}

float4 PS_Censor(VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
	float4 Pixel = tex2Dlod(SampleTempTex0, float4(Input.Tex0, 0.0, 5.0));
	float MaxC = max(max(Pixel.r, Pixel.g), Pixel.b);
	
	return lerp(Color, Pixel, MaxC > 0.5);
}

technique CShade_Censor
{
    pass
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Blit;
        RenderTarget = TempTex0_RGB10A2;
    }

    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        VertexShader = VS_Quad;
        PixelShader = PS_Censor;
    }
}
