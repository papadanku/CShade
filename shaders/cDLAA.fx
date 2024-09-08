
/*
    Directionally Localized Anti-Aliasing (DLAA)
    http://www.and.intercon.ru/releases/talks/dlaagdc2011/

    by Dmitry Andreev
    Copyright (C) LucasArts 2010-2011
*/

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Render Image\0Render Mask\0";
> = 0;

uniform int _ContrastThreshold <
    ui_label = "Long Edge Threshold";
    ui_tooltip = "The minimum amount of noise required to detect long edges.";
    ui_type = "combo";
    ui_items = "Very High\0High\0Medium\0Low\0Very Low\0";
> = 1;

static const float ContrastThresholds[5] =
{
    1.0 / 3.0, 1.0 / 4.0, 1.0 / 6.0, 1.0 / 8.0, 1.0 / 16.0
};

#include "shared/cColor.fxh"

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

    /*
        Short edges
    */
    float4 ShortEdgeTex0 = Input.Tex0.xyxy + (float4(-1.5, 0.0, 1.5, 0.0) * Delta.xyxy);
    float4 ShortEdgeTex1 = Input.Tex0.xyxy + (float4(0.0, -1.5, 0.0, 1.5) * Delta.xyxy);
    float4 ShortEdgeTex2 = Input.Tex0.xyxy + (float4(-1.0, 0.0, 1.0, 0.0) * Delta.xyxy);
    float4 ShortEdgeTex3 = Input.Tex0.xyxy + (float4(0.0, -1.0, 0.0, 1.0) * Delta.xyxy);

    float4 Center = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0, 0.0, 0.0));

    float4 Left01 = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex0.xy, 0.0, 0.0));
    float4 Right01 = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex0.zw, 0.0, 0.0));
    float4 Top01 = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex1.xy, 0.0, 0.0));
    float4 Bottom01 = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex1.zw, 0.0, 0.0));

    float4 Left = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex2.xy, 0.0, 0.0));
    float4 Right = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex2.zw, 0.0, 0.0));
    float4 Top = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex3.xy, 0.0, 0.0));
    float4 Bottom = tex2Dlod(SampleTempTex0, float4(ShortEdgeTex3.zw, 0.0, 0.0));

    float4 WH = 2.0 * (Left01 + Right01);
    float4 WV = 2.0 * (Top01 + Bottom01);

    // 3-pixel wide high-pass
    float4 EdgeH = abs(Left + Right - 2.0 * Center) / 2.0;
    float4 EdgeV = abs(Top + Bottom - 2.0 * Center) / 2.0;

    // Get low-pass
    float4 BlurH = (WH + 2.0 * Center) / 6.0;
    float4 BlurV = (WV + 2.0 * Center) / 6.0;

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
    float4 LTex0 = Input.Tex0.xyxy + (float4(1.5, 0.0, 0.0, 1.5) * Delta.xyxy);
    float4 LTex1 = Input.Tex0.xyxy + (float4(3.5, 0.0, 0.0, 3.5) * Delta.xyxy);
    float4 LTex2 = Input.Tex0.xyxy + (float4(5.5, 0.0, 0.0, 5.5) * Delta.xyxy);
    float4 LTex3 = Input.Tex0.xyxy + (float4(7.5, 0.0, 0.0, 7.5) * Delta.xyxy);
    float4 LTex4 = Input.Tex0.xyxy + (float4(-1.5, 0.0, 0.0, -1.5) * Delta.xyxy);
    float4 LTex5 = Input.Tex0.xyxy + (float4(-3.5, 0.0, 0.0, -3.5) * Delta.xyxy);
    float4 LTex6 = Input.Tex0.xyxy + (float4(-5.5, 0.0, 0.0, -5.5) * Delta.xyxy);
    float4 LTex7 = Input.Tex0.xyxy + (float4(-7.5, 0.0, 0.0, -7.5) * Delta.xyxy);

    float4 H0 = tex2Dlod(SampleTempTex0, float4(LTex0.xy, 0.0, 0.0));
    float4 H1 = tex2Dlod(SampleTempTex0, float4(LTex1.xy, 0.0, 0.0));
    float4 H2 = tex2Dlod(SampleTempTex0, float4(LTex2.xy, 0.0, 0.0));
    float4 H3 = tex2Dlod(SampleTempTex0, float4(LTex3.xy, 0.0, 0.0));
    float4 H4 = tex2Dlod(SampleTempTex0, float4(LTex4.xy, 0.0, 0.0));
    float4 H5 = tex2Dlod(SampleTempTex0, float4(LTex5.xy, 0.0, 0.0));
    float4 H6 = tex2Dlod(SampleTempTex0, float4(LTex6.xy, 0.0, 0.0));
    float4 H7 = tex2Dlod(SampleTempTex0, float4(LTex7.xy, 0.0, 0.0));

    float4 V0 = tex2Dlod(SampleTempTex0, float4(LTex0.zw, 0.0, 0.0));
    float4 V1 = tex2Dlod(SampleTempTex0, float4(LTex1.zw, 0.0, 0.0));
    float4 V2 = tex2Dlod(SampleTempTex0, float4(LTex2.zw, 0.0, 0.0));
    float4 V3 = tex2Dlod(SampleTempTex0, float4(LTex3.zw, 0.0, 0.0));
    float4 V4 = tex2Dlod(SampleTempTex0, float4(LTex4.zw, 0.0, 0.0));
    float4 V5 = tex2Dlod(SampleTempTex0, float4(LTex5.zw, 0.0, 0.0));
    float4 V6 = tex2Dlod(SampleTempTex0, float4(LTex6.zw, 0.0, 0.0));
    float4 V7 = tex2Dlod(SampleTempTex0, float4(LTex7.zw, 0.0, 0.0));

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
        VHXY = (VHXY == float4(0.0, 0.0, 0.0, 0.0)) ? float4(1.0, 1.0, 1.0, 1.0) : VHXY;

        ColorV = lerp(Left, ColorV, VHXY.x);
        ColorV = lerp(Right, ColorV, VHXY.y);
        ColorH = lerp(Top, ColorH, VHXY.z);
        ColorH = lerp(Bottom, ColorH, VHXY.w);

        Color = lerp(Color, ColorV, LongEdgeMaskV);
        Color = lerp(Color, ColorH, LongEdgeMaskH);
    }

    // Preserve high frequencies
    float4 RTex = Input.Tex0.xyxy + (Delta.xyxy * float4(-1.5, -1.5, 1.5, 1.5));
    float4 R0 = tex2Dlod(SampleTempTex0, float4(RTex.xw, 0.0, 0.0));
    float4 R1 = tex2Dlod(SampleTempTex0, float4(RTex.zw, 0.0, 0.0));
    float4 R2 = tex2Dlod(SampleTempTex0, float4(RTex.xy, 0.0, 0.0));
    float4 R3 = tex2Dlod(SampleTempTex0, float4(RTex.zy, 0.0, 0.0));

    float4 R = (4.0 * (R0 + R1 + R2 + R3) + Center + Top01 + Bottom01 + Left01 + Right01) / 25.0;
    Color = lerp(Color, Center, saturate(R.a * 3.0 - 1.5));

    if (_RenderMode == 1)
    {
        return tex2Dlod(SampleTempTex0, float4(Input.Tex0, 0.0, 0.0)).a;
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
