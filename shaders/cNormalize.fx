#define CSHADE_NORMALIZE

#include "shared/cColor.fxh"
#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform int _Select <
    ui_category = "Main Shader";
    ui_items = "Local Contrast Normalization\0Census Transform\0";
    ui_label = "Normalization Filter";
    ui_type = "combo";
    ui_tooltip = "Selects the normalization algorithm to apply, such as Local Contrast Normalization or Census Transform.";
> = 0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

float4 GetCensusTransform(float2 Tex)
{
    float4 Transform = 0.0;

    float2 Delta = fwidth(Tex);
    float4 Tex0 = Tex.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Delta.xyyy);
    float4 Tex1 = Tex.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Delta.xyyy);
    float4 Tex2 = Tex.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Delta.xyyy);

    const int Neighbors = 8;
    float4 SampleNeighbor[Neighbors];
    SampleNeighbor[0] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex0.xy);
    SampleNeighbor[1] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex1.xy);
    SampleNeighbor[2] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex2.xy);
    SampleNeighbor[3] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex0.xz);
    SampleNeighbor[4] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex2.xz);
    SampleNeighbor[5] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex0.xw);
    SampleNeighbor[6] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex1.xw);
    SampleNeighbor[7] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex2.xw);
    float4 CenterSample = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex1.xz);

    // Generate 8-bit integer from the 8-pixel neighborhood
    for (int i = 0; i < Neighbors; i++)
    {
        float4 Comparison = step(SampleNeighbor[i], CenterSample);
        Transform += ldexp(Comparison, i);
    }

    // Convert the 8-bit integer to float
    return Transform * (1.0 / (exp2(8) - 1));
}

float4 GetLocalContrastNormalization(float2 Tex)
{
    float2 Delta = fwidth(Tex);

    float4 S[5];
    S[0] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex);
    S[1] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex + (float2(-1.5, 0.0) * Delta));
    S[2] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex + (float2(1.5, 0.0) * Delta));
    S[3] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex + (float2(0.0, -1.5) * Delta));
    S[4] = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Tex + (float2(0.0, 1.5) * Delta));
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

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    switch (_Select)
    {
        case 0:
            float4 LCN = GetLocalContrastNormalization(Input.Tex0);
            Output.rgb = (float3)CMath_SNORMtoUNORM_FLT1(CColor_RGBtoLuma(LCN.rgb, 0));
            break;
        case 1:
            float4 CT = GetCensusTransform(Input.Tex0);
            Output.rgb = (float3)CColor_RGBtoLuma(CT.rgb, 0);
            break;
        default:
            Output.rgb = 0.5;
            break;
    }

    Output = CBlend_OutputChannels(Output.rgb, _CShade_AlphaFactor);
}

technique CShade_Normalize
<
    ui_label = "CShade / Normalize";
    ui_tooltip = "Local normalization algorithms.";
>
{
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
