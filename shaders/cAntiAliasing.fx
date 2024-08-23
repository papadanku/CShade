
/*
    Single-Pass FXAA modification of:
        - https://bitbucket.org/catlikecodingunitytutorials/custom-srp-17-fxaa/src
        - https://catlikecoding.com/unity/tutorials/custom-srp/fxaa/

    MIT No Attribution (MIT-0)

    Copyright 2021 Jasper Flick

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#define CONTRAST_THRESHOLD 0.0312
#define RELATIVE_THRESHOLD 0.063
#define SUBPIXEL_BLENDING 0.75

#include "shared/cShade.fxh"
#include "shared/cColor.fxh"
#include "shared/cBlend.fxh"

float GetLuma(float3 Color)
{
    return CColor_GetLuma(Color, 0);
}

float SampleLuma(float2 Tex, float2 Offset, float2 Delta)
{
    float4 Tex1 = float4(Tex + (Offset * Delta), 0.0, 0.0);
    float3 Color = tex2Dlod(CShade_SampleGammaTex, Tex1).rgb;
    return GetLuma(Color);
}

struct LumaNeighborhood
{
    float M, N, E, S, W;
    float Highest, Lowest, Range;
};

LumaNeighborhood GetLumaNeighborhood(float2 Tex, float2 Delta)
{
    LumaNeighborhood L;
    L.M = SampleLuma(Tex, float2(0.0, 0.0), Delta);
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
    return Blend * Blend * SUBPIXEL_BLENDING;
}

bool IsHorizontalEdge(LumaNeighborhood LN, LumaDiagonals LD)
{
    float Horizontal =
        2.0 * abs(LN.N + LN.S - 2.0 * LN.M) +
        abs(LD.NE + LD.SE - 2.0 * LN.E) +
        abs(LD.NW + LD.SW - 2.0 * LN.W);
    float Vertical =
        2.0 * abs(LN.E + LN.W - 2.0 * LN.M) +
        abs(LD.NE + LD.NW - 2.0 * LN.N) +
        abs(LD.SE + LD.SW - 2.0 * LN.S);
    return Horizontal >= Vertical;
}

bool SkipFXAA(LumaNeighborhood LN)
{
    return LN.Range < max(CONTRAST_THRESHOLD, RELATIVE_THRESHOLD * LN.Highest);
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
    const int EdgeStepCount = 4;
    const float EdgeSteps[EdgeStepCount] = { 1.0, 1.5, 2.0, 4.0 };
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

float4 PS_AntiAliasing(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Delta = fwidth(Input.Tex0);
    LumaNeighborhood LN = GetLumaNeighborhood(Input.Tex0, Delta);
    float2 BlendTex = Input.Tex0;

    [branch]
    if (!SkipFXAA(LN))
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
    }

    float4 FXAA = tex2Dlod(CShade_SampleColorTex, float4(BlendTex, 0.0, 0.0));
    return CBlend_OutputChannels(float4(FXAA.rgb, _CShadeAlphaFactor));
}

technique CShade_AntiAliasing
{
    pass AntiAliasing
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_AntiAliasing;
    }
}
