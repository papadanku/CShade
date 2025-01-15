#define CSHADE_FXAA

/*
    Single-Pass FXAA modification of:
        - https://bitbucket.org/catlikecodingunitytutorials/custom-srp-17-fxaa/src
        - https://catlikecoding.com/unity/tutorials/custom-srp/fxaa/

    MIT No Attribution (MIT-0)

    Copyright 2021 Jasper Flick

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "shared/cColor.fxh"

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Directions\0";
> = 0;

uniform int _RelativeThreshold <
    ui_category = "Fast Approximate Anti-Aliasing";
    ui_label = "Relative Threshold";
    ui_tooltip = "Trims the algorithm from processing darks.";
    ui_type = "combo";
    ui_items = "High\0Medium\0Low\0";
> = 1;

static const float RelativeThresholds[3] =
{
    1.0 / 12.0, 1.0 / 16.0, 1.0 / 32.0
};

uniform int _ContrastThreshold <
    ui_category = "Fast Approximate Anti-Aliasing";
    ui_label = "Contrast Threshold";
    ui_tooltip = "The minimum amount of local contrast required to apply algorithm.";
    ui_type = "combo";
    ui_items = "Very High\0High\0Medium\0Low\0Very Low\0";
> = 2;

static const float ContrastThresholds[5] =
{
    1.0 / 3.0, 1.0 / 4.0, 1.0 / 6.0, 1.0 / 8.0, 1.0 / 16.0
};

uniform int _SubpixelBlending <
    ui_category = "Fast Approximate Anti-Aliasing";
    ui_label = "Subpixel Blending";
    ui_tooltip = "Choose the amount of sub-pixel aliasing removal.";
    ui_type = "combo";
    ui_items = "High\0Medium\0Low\0Very Low\0Off\0";
> = 1;

static const float SubpixelBlendings[5] =
{
    1.0, 3.0 / 4.0, 1.0 / 2.0, 1.0 / 4.0, 0.0
};

#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

float SampleLuma(float2 Tex, float2 Offset, float2 Delta)
{
    float4 Tex1 = float4(Tex + (Offset * Delta), 0.0, 0.0);
    float3 Color = tex2Dlod(CShade_SampleGammaTex, Tex1).rgb;
    return dot(Color, CColor_Rec709_Coefficients);
}

struct LumaNeighborhood
{
    float4 C;
    float M, N, E, S, W;
    float Highest, Lowest, Range;
};

LumaNeighborhood GetLumaNeighborhood(float2 Tex, float2 Delta)
{
    LumaNeighborhood L;
    L.C = tex2Dlod(CShade_SampleGammaTex, float4(Tex, 0.0, 0.0));
    L.M = dot(L.C.rgb, CColor_Rec709_Coefficients);
    L.N = SampleLuma(Tex, float2(0.0, 1.0), Delta);
    L.E = SampleLuma(Tex, float2(1.0, 0.0), Delta);
    L.S = SampleLuma(Tex, float2(0.0, -1.0), Delta);
    L.W = SampleLuma(Tex, float2(-1.0, 0.0), Delta);
    L.Highest = max(max(max(max(L.M, L.N), L.E), L.S), L.W);
    L.Lowest = min(min(min(min(L.M, L.N), L.E), L.S), L.W);
    L.Range = L.Highest - L.Lowest;
    return L;
}

struct LumaDiagonals
{
    float NE, SE, SW, NW;
};

LumaDiagonals GetLumaDiagonals(float2 Tex, float2 Delta)
{
    LumaDiagonals L;
    L.NE = SampleLuma(Tex, float2(1.0, 1.0), Delta);
    L.SE = SampleLuma(Tex, float2(1.0, -1.0), Delta);
    L.SW = SampleLuma(Tex, float2(-1.0, -1.0), Delta);
    L.NW = SampleLuma(Tex, float2(-1.0, 1.0), Delta);
    return L;
}

float GetSubpixelBlendFactor(LumaNeighborhood LN, LumaDiagonals LD)
{
    float Blend = 2.0 * (LN.N + LN.E + LN.S + LN.W);
    Blend += LD.NE + LD.NW + LD.SE + LD.SW;
    Blend *= (1.0 / 12.0);
    Blend = abs(Blend - LN.M);
    Blend = saturate(Blend / LN.Range);
    Blend = smoothstep(0.0, 1.0, Blend);
    return Blend * Blend * SubpixelBlendings[_SubpixelBlending];
}

bool IsHorizontalEdge(LumaNeighborhood LN, LumaDiagonals LD)
{
    float Horizontal = 0.0;
    Horizontal += 2.0 * abs(LN.N + LN.S - (2.0 * LN.M));
    Horizontal += abs(LD.NE + LD.SE - (2.0 * LN.E));
    Horizontal += abs(LD.NW + LD.SW - (2.0 * LN.W));
    float Vertical = 0.0;
    Vertical += 2.0 * abs(LN.E + LN.W - (2.0 * LN.M));
    Vertical += abs(LD.NE + LD.NW - (2.0 * LN.N));
    Vertical += abs(LD.SE + LD.SW - (2.0 * LN.S));
    return Horizontal >= Vertical;
}

bool SkipFXAA(LumaNeighborhood LN)
{
    return LN.Range < max(RelativeThresholds[_RelativeThreshold], ContrastThresholds[_ContrastThreshold] * LN.Highest);
}

struct Edge
{
    bool IsHorizontal;
    float PixelStep;
    float LumaGradient, OtherLuma;
};

Edge GetEdge(LumaNeighborhood LN, LumaDiagonals LD, float2 Delta)
{
    Edge E;
    E.IsHorizontal = IsHorizontalEdge(LN, LD);
    E.PixelStep = (E.IsHorizontal) ? Delta.y : Delta.x;
    float LumaP = (E.IsHorizontal) ? LN.N : LN.E;
    float LumaN = (E.IsHorizontal) ? LN.S : LN.W;

    float GradientP = abs(LumaP - LN.M);
    float GradientN = abs(LumaN - LN.M);
    if (GradientP < GradientN)
    {
        E.PixelStep = -E.PixelStep;
        E.LumaGradient = GradientN;
        E.OtherLuma = LumaN;
    }
    else
    {
        E.LumaGradient = GradientP;
        E.OtherLuma = LumaP;
    }

    return E;
}

float GetEdgeBlendFactor(LumaNeighborhood LN, LumaDiagonals LD, Edge E, float2 Tex, float2 Delta)
{
    const int EdgeStepCount = 7;
    const float EdgeSteps[EdgeStepCount] = { 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0 };
    const float LastStep = 12.0;

    float2 EdgeTex = Tex;
    float2 TexStep = 0.0;
    if (E.IsHorizontal)
    {
        EdgeTex.y += (E.PixelStep * 0.5);
        TexStep.x = Delta.x;
    }
    else
    {
        EdgeTex.x += (E.PixelStep * 0.5);
        TexStep.y = Delta.y;
    }

    // Precompute this
    float EdgeLuma = 0.5 * (LN.M + E.OtherLuma);
    float GradientThreshold = 0.25 * E.LumaGradient;

    // March in the positive direction
    float2 TexP = EdgeTex + TexStep;
    float LumaDeltaP = SampleLuma(TexP, 0.0, Delta) - EdgeLuma;
    bool AtEndP = abs(LumaDeltaP) >= GradientThreshold;
    [unroll]
    for (int i = 0; i < EdgeStepCount && !AtEndP; i++)
    {
        TexP += (TexStep * EdgeSteps[i]);
        LumaDeltaP = SampleLuma(TexP, 0.0, Delta) - EdgeLuma;
        AtEndP = abs(LumaDeltaP) >= GradientThreshold;
    }
    if (!AtEndP)
    {
        TexP += (TexStep * LastStep);
    }

    // March in the negative direction
    float2 TexN = EdgeTex - TexStep;
    float LumaDeltaN = SampleLuma(TexN, 0.0, Delta) - EdgeLuma;
    bool AtEndN = abs(LumaDeltaN) >= GradientThreshold;
    [unroll]
    for (int i = 0; i < EdgeStepCount && !AtEndN; i++)
    {
        TexN -= (TexStep * EdgeSteps[i]);
        LumaDeltaN = SampleLuma(TexN, 0.0, Delta) - EdgeLuma;
        AtEndN = abs(LumaDeltaN) >= GradientThreshold;
    }
    if (!AtEndN)
    {
        TexN -= (TexStep * LastStep);
    }

    float DistanceToEndP = (E.IsHorizontal) ? TexP.x - Tex.x : TexP.y - Tex.y;
    float DistanceToEndN = (E.IsHorizontal) ? Tex.x - TexN.x : Tex.y - TexN.y;

    float DistanceToNearestEnd = 0.0;
    float DeltaSign = 0.0;

    if (DistanceToEndP <= DistanceToEndN)
    {
        DistanceToNearestEnd = DistanceToEndP;
        DeltaSign = LumaDeltaP >= 0;
    }
    else
    {
        DistanceToNearestEnd = DistanceToEndN;
        DeltaSign = LumaDeltaN >= 0;
    }

    if (DeltaSign == (LN.M - EdgeLuma >= 0))
    {
        return 0.0;
    }
    else
    {
        return 0.5 - DistanceToNearestEnd / (DistanceToEndP + DistanceToEndN);
    }
}

float4 PS_FXAA(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Delta = fwidth(Input.Tex0);
    LumaNeighborhood LN = GetLumaNeighborhood(Input.Tex0, Delta);
    float3 FXAA = 0.0;
    float2 BlendTex = Input.Tex0;

    [branch]
    if (SkipFXAA(LN))
    {
        FXAA = LN.C.rgb;
    }
    else
    {
        LumaDiagonals LD = GetLumaDiagonals(Input.Tex0, Delta);
        Edge E = GetEdge(LN, LD, Delta);

        float SubpixelBlendFactor = GetSubpixelBlendFactor(LN, LD);
        float EdgeBlendFactor = GetEdgeBlendFactor(LN, LD, E, Input.Tex0, Delta);
        float BlendFactor = max(SubpixelBlendFactor, EdgeBlendFactor);

        if (E.IsHorizontal)
        {
            BlendTex.y += (BlendFactor * E.PixelStep);
        }
        else
        {
            BlendTex.x += (BlendFactor * E.PixelStep);
        }

        FXAA = tex2Dlod(CShade_SampleGammaTex, float4(BlendTex, 0.0, 0.0)).rgb;
    }

    if (_RenderMode == 1)
    {
        FXAA = float3(Input.Tex0 - BlendTex, 0.0);
        FXAA.xy = (normalize(FXAA.xy) * 0.5) + 0.5;
    }

    return CBlend_OutputChannels(float4(FXAA, _CShadeAlphaFactor));
}

technique CShade_FXAA < ui_tooltip = "Fast Approximate Anti-Aliasing (FXAA)"; >
{
    pass FXAA
    {
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_FXAA;
    }
}
