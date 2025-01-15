#define CSHADE_DLAA

/*
    Directionally Localized Anti-Aliasing (DLAA)
    http://www.and.intercon.ru/releases/talks/dlaagdc2011/

    by Dmitry Andreev
    Copyright (C) LucasArts 2010-2011
*/

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Short Edge Mask\0Long Edge Mask\0";
> = 0;

uniform int _ContrastThreshold <
    ui_label = "Long Edge Threshold";
    ui_tooltip = "The minimum amount of noise required to detect long edges.";
    ui_type = "combo";
    ui_items = "Very High\0High\0Medium\0Low\0Very Low\0";
> = 1;

uniform bool _PreserveFrequencies <
    ui_label = "Preserve High Frequencies";
    ui_type = "radio";
> = true;

static const float ContrastThresholds[5] =
{
    1.0 / 3.0, 1.0 / 4.0, 1.0 / 6.0, 1.0 / 8.0, 1.0 / 16.0
};

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

CREATE_TEXTURE_POOLED(TempTex0_RGBA8, BUFFER_SIZE_0, RGBA8, 0)
CREATE_SAMPLER(SampleTempTex0, TempTex0_RGBA8, LINEAR, MIRROR, MIRROR, MIRROR)

float GetIntensity(float3 Color)
{
    return dot(Color, 1.0 / 3.0);
}

float4 PS_Prefilter(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Delta = fwidth(Input.Tex0.xy);
    float4 EdgeTex0 = Input.Tex0.xyxy + (float4(-1.0, 0.0, 1.0, 0.0) * Delta.xyxy);
    float4 EdgeTex1 = Input.Tex0.xyxy + (float4(0.0, -1.0, 0.0, 1.0) * Delta.xyxy);

    float3 Neighborhood[4];
    float3 Center = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0, 0.0, 0.0)).rgb;
    Neighborhood[0] = tex2Dlod(CShade_SampleGammaTex, float4(EdgeTex0.xy, 0.0, 0.0)).rgb;
    Neighborhood[1] = tex2Dlod(CShade_SampleGammaTex, float4(EdgeTex0.zw, 0.0, 0.0)).rgb;
    Neighborhood[2] = tex2Dlod(CShade_SampleGammaTex, float4(EdgeTex1.xy, 0.0, 0.0)).rgb;
    Neighborhood[3] = tex2Dlod(CShade_SampleGammaTex, float4(EdgeTex1.zw, 0.0, 0.0)).rgb;

    // Compass edge detection on N/S/E/W
    float3 Edges = 0.0;
    Edges = max(Edges, abs(Center - Neighborhood[0]));
    Edges = max(Edges, abs(Center - Neighborhood[1]));
    Edges = max(Edges, abs(Center - Neighborhood[2]));
    Edges = max(Edges, abs(Center - Neighborhood[3]));

    // It costs more ALU, but we should do the multiplication in the sampling pass for precision reasons
    return float4(Center, smoothstep(0.0, 0.25, GetIntensity(Edges)));
}

float4 PS_DLAA(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Delta = fwidth(Input.Tex0);

    const float Lambda = 3.0;
    const float Epsilon = 0.1;

    float4 Center = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0, 0.0, 0.0));

    float4 ShortTex1 = Input.Tex0.xyxy + (float4(-1.0, 0.0, 1.0, 0.0) * Delta.xyxy);
    float4 ShortTex2 = Input.Tex0.xyxy + (float4(0.0, -1.0, 0.0, 1.0) * Delta.xyxy);

    float4 Left = tex2Dlod(SampleTempTex0, float4(ShortTex1.xy, 0.0, 0.0));
    float4 Right = tex2Dlod(SampleTempTex0, float4(ShortTex1.zw, 0.0, 0.0));
    float4 Top = tex2Dlod(SampleTempTex0, float4(ShortTex2.xy, 0.0, 0.0));
    float4 Bottom = tex2Dlod(SampleTempTex0, float4(ShortTex2.zw, 0.0, 0.0));

    float4 LongTex0 = Input.Tex0.xyxy + (float4(1.5, 0.0, 0.0, 1.5) * Delta.xyxy);
    float4 LongTex1 = Input.Tex0.xyxy + (float4(3.5, 0.0, 0.0, 3.5) * Delta.xyxy);
    float4 LongTex2 = Input.Tex0.xyxy + (float4(5.5, 0.0, 0.0, 5.5) * Delta.xyxy);
    float4 LongTex3 = Input.Tex0.xyxy + (float4(7.5, 0.0, 0.0, 7.5) * Delta.xyxy);
    float4 LongTex4 = Input.Tex0.xyxy + (float4(-1.5, 0.0, 0.0, -1.5) * Delta.xyxy);
    float4 LongTex5 = Input.Tex0.xyxy + (float4(-3.5, 0.0, 0.0, -3.5) * Delta.xyxy);
    float4 LongTex6 = Input.Tex0.xyxy + (float4(-5.5, 0.0, 0.0, -5.5) * Delta.xyxy);
    float4 LongTex7 = Input.Tex0.xyxy + (float4(-7.5, 0.0, 0.0, -7.5) * Delta.xyxy);

    float4 H0 = tex2Dlod(SampleTempTex0, float4(LongTex0.xy, 0.0, 0.0));
    float4 H1 = tex2Dlod(SampleTempTex0, float4(LongTex1.xy, 0.0, 0.0));
    float4 H2 = tex2Dlod(SampleTempTex0, float4(LongTex2.xy, 0.0, 0.0));
    float4 H3 = tex2Dlod(SampleTempTex0, float4(LongTex3.xy, 0.0, 0.0));
    float4 H4 = tex2Dlod(SampleTempTex0, float4(LongTex4.xy, 0.0, 0.0));
    float4 H5 = tex2Dlod(SampleTempTex0, float4(LongTex5.xy, 0.0, 0.0));
    float4 H6 = tex2Dlod(SampleTempTex0, float4(LongTex6.xy, 0.0, 0.0));
    float4 H7 = tex2Dlod(SampleTempTex0, float4(LongTex7.xy, 0.0, 0.0));

    float4 V0 = tex2Dlod(SampleTempTex0, float4(LongTex0.zw, 0.0, 0.0));
    float4 V1 = tex2Dlod(SampleTempTex0, float4(LongTex1.zw, 0.0, 0.0));
    float4 V2 = tex2Dlod(SampleTempTex0, float4(LongTex2.zw, 0.0, 0.0));
    float4 V3 = tex2Dlod(SampleTempTex0, float4(LongTex3.zw, 0.0, 0.0));
    float4 V4 = tex2Dlod(SampleTempTex0, float4(LongTex4.zw, 0.0, 0.0));
    float4 V5 = tex2Dlod(SampleTempTex0, float4(LongTex5.zw, 0.0, 0.0));
    float4 V6 = tex2Dlod(SampleTempTex0, float4(LongTex6.zw, 0.0, 0.0));
    float4 V7 = tex2Dlod(SampleTempTex0, float4(LongTex7.zw, 0.0, 0.0));

    /*
        Short edges
    */

    // 3-pixel wide high-pass
    float4 EdgeH = abs((Left + Right) - (2.0 * Center)) / 2.0;
    float4 EdgeV = abs((Top + Bottom) - (2.0 * Center)) / 2.0;

    // Get low-pass
    float4 WH = 2.0 * (H4 + H0);
    float4 WV = 2.0 * (V0 + V4);
    float4 BlurH = (WH + (2.0 * Center)) / 6.0;
    float4 BlurV = (WV + (2.0 * Center)) / 6.0;

    // Get respective intensities
    float EdgeLumaH = GetIntensity(EdgeH.rgb);
    float EdgeLumaV = GetIntensity(EdgeV.rgb);
    float BlurLumaH = GetIntensity(BlurH.rgb);
    float BlurLumaV = GetIntensity(BlurV.rgb);

    // Edge masks
    float EdgeMaskH = saturate((Lambda * EdgeLumaH - Epsilon) / BlurLumaV);
    float EdgeMaskV = saturate((Lambda * EdgeLumaV - Epsilon) / BlurLumaH);

    float4 Color = Center;
    Color = lerp(Color, BlurH, EdgeMaskV);
    Color = lerp(Color, BlurV, EdgeMaskH);

    /*
        Long edges
    */

    // In CShade, we take .rgb out of branch
    float4 LongBlurH = (H0 + H1 + H2 + H3 + H4 + H5 + H6 + H7) / 8.0;
    float4 LongBlurV = (V0 + V1 + V2 + V3 + V4 + V5 + V6 + V7) / 8.0;

    float LongEdgeMaskH = saturate((LongBlurH.a * 2.0) - 1.0);
    float LongEdgeMaskV = saturate((LongBlurV.a * 2.0) - 1.0);

    [branch]
    if (abs(LongEdgeMaskH - LongEdgeMaskV) > ContrastThresholds[_ContrastThreshold])
    {
        float LongBlurLumaH = GetIntensity(LongBlurH.rgb);
        float LongBlurLumaV = GetIntensity(LongBlurV.rgb);

        float CenterLuma = GetIntensity(Center.rgb);
        float LeftLuma = GetIntensity(Left.rgb);
        float RightLuma = GetIntensity(Right.rgb);
        float TopLuma = GetIntensity(Top.rgb);
        float BottomLuma = GetIntensity(Bottom.rgb);

        float4 ColorH = Center;
        float4 ColorV = Center;

        // Vectorized search
        float HX = saturate(0.0 + (LongBlurLumaH - TopLuma) / (CenterLuma - TopLuma));
        float HY = saturate(1.0 + (LongBlurLumaH - CenterLuma) / (CenterLuma - BottomLuma));
        float VX = saturate(0.0 + (LongBlurLumaV - LeftLuma) / (CenterLuma - LeftLuma));
        float VY = saturate(1.0 + (LongBlurLumaV - CenterLuma) / (CenterLuma - RightLuma));

        float4 VHXY = float4(VX, VY, HX, HY);
        VHXY = (VHXY == 0.0) ? 1.0 : VHXY;

        ColorV = lerp(Left, ColorV, VHXY.x);
        ColorV = lerp(Right, ColorV, VHXY.y);
        ColorH = lerp(Top, ColorH, VHXY.z);
        ColorH = lerp(Bottom, ColorH, VHXY.w);

        Color = lerp(Color, ColorV, LongEdgeMaskV);
        Color = lerp(Color, ColorH, LongEdgeMaskH);
    }

    // Preserve high frequencies
    if (_PreserveFrequencies)
    {
        float4 RTex = Input.Tex0.xyxy + (Delta.xyxy * float4(-1.5, -1.5, 1.5, 1.5));
        float4 R0 = tex2Dlod(SampleTempTex0, float4(RTex.xw, 0.0, 0.0));
        float4 R1 = tex2Dlod(SampleTempTex0, float4(RTex.zw, 0.0, 0.0));
        float4 R2 = tex2Dlod(SampleTempTex0, float4(RTex.xy, 0.0, 0.0));
        float4 R3 = tex2Dlod(SampleTempTex0, float4(RTex.zy, 0.0, 0.0));

        float4 R = (4.0 * (R0 + R1 + R2 + R3) + Center + V0 + V4 + H4 + H0) / 25.0;
        Color = lerp(Color, Center, saturate(R.a * 3.0 - 1.5));
    }

    switch (_RenderMode)
    {
        case 1:
            Color = float4(EdgeMaskH, EdgeMaskV, 0.0, 0.0);
            break;
        case 2:
            Color = float4(LongEdgeMaskH, LongEdgeMaskV, 0.0, 0.0);
            break;
    }

    return CBlend_OutputChannels(float4(Color.rgb, _CShadeAlphaFactor));
}

technique CShade_DLAA < ui_tooltip = "Directionally Localized Anti-Aliasing (DLAA)"; >
{
    pass PreFilter
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Prefilter;
        RenderTarget0 = TempTex0_RGBA8;
    }

    pass DLAA
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_DLAA;
    }
}
