#include "shared/cGraphics.fxh"

/*
    [Shader Options]
*/

uniform float _Weight <
    ui_label = "Sharpen Weight";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 10.0;
> = 1.0;

/*
    [Pixel Shaders]
*/

float4 PS_Shard(VS2PS_Quad Input) : SV_TARGET0
{
    float2 Tex0 = Input.Tex0.xy;
    float4 Tex1 = Tex0.xyxy + (fwidth(Tex0).xyxy * float4(-1.0, -1.0, 1.0, 1.0));
    float4 OriginalSample = tex2D(CShade_SampleColorTex, Tex0.xy);
    float4 BlurSample = 0.0;
    BlurSample += tex2D(CShade_SampleColorTex, Tex1.xw) * 0.25;
    BlurSample += tex2D(CShade_SampleColorTex, Tex1.zw) * 0.25;
    BlurSample += tex2D(CShade_SampleColorTex, Tex1.xy) * 0.25;
    BlurSample += tex2D(CShade_SampleColorTex, Tex1.zy) * 0.25;
    return OriginalSample + (OriginalSample - BlurSample) * _Weight;
}

technique CShade_Shard
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Shard;
    }
}
