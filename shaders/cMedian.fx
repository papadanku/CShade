
#include "shared/cGraphics.fxh"
#include "shared/cMath.fxh"

/*
    [Pixel Shaders]
*/

float4 PS_Median(VS2PS_Quad Input) : SV_TARGET0
{
    float2 PixelSize = fwidth(Input.Tex0.xy);
    float4 Tex0 = Input.Tex0.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    float4 Tex1 = Input.Tex0.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    float4 Tex2 = Input.Tex0.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);

    // Sample locations:
    // [0].xy [1].xy [2].xy
    // [0].xz [1].xz [2].xz
    // [0].xw [1].xw [2].xw
    float4 Sample[9];
    Sample[0] = tex2D(CShade_SampleColorTex, Tex0.xy);
    Sample[1] = tex2D(CShade_SampleColorTex, Tex1.xy);
    Sample[2] = tex2D(CShade_SampleColorTex, Tex2.xy);
    Sample[3] = tex2D(CShade_SampleColorTex, Tex0.xz);
    Sample[4] = tex2D(CShade_SampleColorTex, Tex1.xz);
    Sample[5] = tex2D(CShade_SampleColorTex, Tex2.xz);
    Sample[6] = tex2D(CShade_SampleColorTex, Tex0.xw);
    Sample[7] = tex2D(CShade_SampleColorTex, Tex1.xw);
    Sample[8] = tex2D(CShade_SampleColorTex, Tex2.xw);
    return Med9(Sample[0], Sample[1], Sample[2],
                Sample[3], Sample[4], Sample[5],
                Sample[6], Sample[7], Sample[8]);
}

technique CShade_Median
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Median;
    }
}
