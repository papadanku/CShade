
#include "shared/cGraphics.fxh"
#include "shared/cColorSpaces.fxh"

float GetIntensity(float3 Color)
{
    return CColorSpaces_GetLuma(Color, 0);
}

float4 PS_Prefilter(VS2PS_Quad Input) : SV_TARGET0
{
    float2 Delta = fwidth(Input.Tex0.xy);
    float4 Tex = Input.Tex0.xyxy + (Delta.xyxy * float4(-0.5, -0.5, 0.5, 0.5));
    float3 SampleA = tex2D(CShade_SampleGammaTex, Tex.xw).rgb;
    float3 SampleB = tex2D(CShade_SampleGammaTex, Tex.zw).rgb;
    float3 SampleC = tex2D(CShade_SampleGammaTex, Tex.xy).rgb;
    float3 SampleD = tex2D(CShade_SampleGammaTex, Tex.zy).rgb;
    float3 SampleE = tex2D(CShade_SampleGammaTex, Input.Tex0).rgb;
    float3 Edges = 4.0 * abs((SampleA + SampleB + SampleC + SampleD) - (SampleE * 4.0));
    float EdgesLuma = GetIntensity(Edges);

    return float4(SampleE, EdgesLuma);
}

float4 PS_AntiAliasing(VS2PS_Quad Input) : SV_TARGET0
{
    float2 Delta = fwidth(Input.Tex0);

    const float Lambda = 3.0;
    const float Epsilon = 0.1;

    /*
        Short edges
    */
    float4 Center = tex2D(CShade_SampleGammaTex, Input.Tex0);
    float4 Left01 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-1.5, 0.0)));
    float4 Right01 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(1.5, 0.0)));
    float4 Top01 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, -1.5)));
    float4 Bottom01 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, 1.5)));

	float4 Left = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0 + (Delta * float2(-1.0, 0.0)), 0.0, 0.0));
	float4 Right = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0 + (Delta * float2(1.0, 0.0)), 0.0, 0.0));
	float4 Top = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0 + (Delta * float2(0.0, -1.0)), 0.0, 0.0));
	float4 Bottom = tex2Dlod(CShade_SampleGammaTex, float4(Input.Tex0 + (Delta * float2(0.0, 1.0)), 0.0, 0.0));

    float4 WH = 2.0 * (Left01 + Right01);
    float4 WV = 2.0 * (Top01 + Bottom01);

    // Softer (5-pixel wide high-pass)
    float4 EdgeH = abs(Left + Right - 2.0 * Center) / 2.0;
    float4 EdgeV = abs(Top + Bottom - 2.0 * Center) / 2.0;

    // Get low-pass
    float4 BlurH = (WH + 2.0f * Center) / 6.0;
    float4 BlurV = (WV + 2.0f * Center) / 6.0;

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

    float4 H0 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(1.5, 0.0)));
    float4 H1 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(3.5, 0.0)));
    float4 H2 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(5.5, 0.0)));
    float4 H3 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(7.5, 0.0)));
    float4 H4 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-1.5, 0.0)));
    float4 H5 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-3.5, 0.0)));
    float4 H6 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-5.5, 0.0)));
    float4 H7 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-7.5, 0.0)));

    float4 V0 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, 1.5)));
    float4 V1 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, 3.5)));
    float4 V2 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, 5.5)));
    float4 V3 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, 7.5)));
    float4 V4 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, -1.5)));
    float4 V5 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, -3.5)));
    float4 V6 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, -5.5)));
    float4 V7 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(0.0, -7.5)));

    // In CShade, we take .rgb out of branch
    float4 LongBlurH = (H0 + H1 + H2 + H3 + H4 + H5 + H6 + H7) / 8.0;
    float4 LongBlurV = (V0 + V1 + V2 + V3 + V4 + V5 + V6 + V7) / 8.0;

    float LongEdgeMaskH = saturate((LongBlurH.a * 2.0) - 1.0);
    float LongEdgeMaskV = saturate((LongBlurV.a * 2.0) - 1.0);

    [branch]
    if (LongEdgeMaskH > 0.0 || LongEdgeMaskV > 0.0)
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

        Color = lerp( Color, ColorV, LongEdgeMaskV);
        Color = lerp( Color, ColorH, LongEdgeMaskH);
    }
    
    float4 R0 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-1.5, -1.5)));
	float4 R1 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(1.5, -1.5)));
	float4 R2 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(-1.5, 1.5)));
	float4 R3 = tex2D(CShade_SampleGammaTex, Input.Tex0 + (Delta * float2(1.5, 1.5)));
        
    float4 R = (4.0 * (R0 + R1 + R2 + R3) + Center + Top01 + Bottom01 + Left01 + Right01) / 25.0;
    Color = lerp(Color, Center, saturate(R.a * 3.0 - 1.5));

    return Color;
}

technique CShade_AntiAliasing
{
    pass PreFilter
    {
        VertexShader = VS_Quad;
        PixelShader = PS_Prefilter;
    }
    
    pass AntiAliasing
    {
    	VertexShader = VS_Quad;
    	PixelShader = PS_AntiAliasing;
    }
}
