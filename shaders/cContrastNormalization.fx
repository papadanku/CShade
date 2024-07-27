
#include "shared/cShade.fxh"
#include "shared/cMath.fxh"

uniform int _Select <
    ui_label = "Filter";
    ui_type = "combo";
    ui_items = "Local Contrast Normalization\0Census Transform\0";
> = 0;

/*
    [Pixel Shaders]
*/

float4 GetCensusTransform(sampler2D Image, float2 Tex)
{
    float4 Transform = 0.0;

    float2 Delta = fwidth(Tex);
    float4 Tex0 = Tex.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Delta.xyyy);
    float4 Tex1 = Tex.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Delta.xyyy);
    float4 Tex2 = Tex.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Delta.xyyy);

    const int Neighbors = 8;
    float4 SampleNeighbor[Neighbors];
    SampleNeighbor[0] = tex2D(CShade_SampleColorTex, Tex0.xy);
    SampleNeighbor[1] = tex2D(CShade_SampleColorTex, Tex1.xy);
    SampleNeighbor[2] = tex2D(CShade_SampleColorTex, Tex2.xy);
    SampleNeighbor[3] = tex2D(CShade_SampleColorTex, Tex0.xz);
    SampleNeighbor[4] = tex2D(CShade_SampleColorTex, Tex2.xz);
    SampleNeighbor[5] = tex2D(CShade_SampleColorTex, Tex0.xw);
    SampleNeighbor[6] = tex2D(CShade_SampleColorTex, Tex1.xw);
    SampleNeighbor[7] = tex2D(CShade_SampleColorTex, Tex2.xw);
    float4 CenterSample = tex2D(CShade_SampleColorTex, Tex1.xz);

    // Generate 8-bit integer from the 8-pixel neighborhood
    for(int i = 0; i < Neighbors; i++)
    {
        float4 Comparison = step(SampleNeighbor[i], CenterSample);
        Transform += ldexp(Comparison, i);
    }

    // Convert the 8-bit integer to float
    return Transform * (1.0 / (exp2(8) - 1));
}

float4 GetLocalContrastNormalization(sampler2D Image, float2 Tex)
{
    float2 Delta = fwidth(Tex);

    float4 S[5];
    S[0] = tex2D(Image, Tex);
    S[1] = tex2D(Image, Tex + (float2(-1.5, 0.0) * Delta));
    S[2] = tex2D(Image, Tex + (float2(1.5, 0.0) * Delta));
    S[3] = tex2D(Image, Tex + (float2(0.0, -1.5) * Delta));
    S[4] = tex2D(Image, Tex + (float2(0.0, 1.5) * Delta));
    float4 Mean = (S[0] + S[1] + S[2] + S[3] + S[4]) / 5.0;

    // Calculate standard deviation
    float4 StdDev = 0.0;
    for (int i = 0; i < 5; i++)
    {
        float4 G = S[i] - Mean;
        StdDev += (G * G);
    }

    StdDev = sqrt(max(StdDev / 5.0, 1e-6));
    return (S[0] - Mean) / StdDev;
}

float4 PS_ContrastNormalization(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    switch (_Select)
    {
        case 0:
            float4 LCN = GetLocalContrastNormalization(CShade_SampleColorTex, Input.Tex0);
            return (dot(LCN.rgb, 1.0 / 3.0) * 0.5) + 0.5;
        case 1:
            float4 CT = GetCensusTransform(CShade_SampleColorTex, Input.Tex0);
            return dot(CT.rgb, 1.0 / 3.0);
        default:
            return 0.5;
    }
}

technique CShade_ContrastNormalization
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_ContrastNormalization;
    }
}
