#define CSHADE_LENS

/*
    Modification of AMD's lens algorithm using gradient noise.

    Source: https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/sdk/include/FidelityFX/gpu/lens/ffx_lens.h

    This file is part of the FidelityFX SDK.

    Copyright (C) 2024 Advanced Micro Devices, Inc.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files(the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions :

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

#include "shared/cMath.fxh"
#include "shared/cLens.fxh"

/*
    [Shader Options]
*/

uniform float _Time < source = "timer"; >;

uniform bool _UseTimeSeed <
    ui_category = "Main Shader";
    ui_label = "Enable Time Seed";
    ui_type = "radio";
> = true;

uniform float _GrainSeed <
    ui_category = "Main Shader";
    ui_label = "Seed Offset";
    ui_type = "drag";
> = 0.0;

uniform float _GrainSeedSpeed <
    ui_category = "Main Shader";
    ui_label = "Seed Speed";
    ui_type = "slider";
    ui_min = 0.1;
    ui_max = 1.0;
> = 0.5;

uniform float _GrainScale <
    ui_category = "Main Shader";
    ui_text = " ";
    ui_label = "Grain Scale";
    ui_type = "slider";
    ui_min = 0.01;
    ui_max = 20.0;
> = 0.01;

uniform float _GrainAmount <
    ui_category = "Main Shader";
    ui_label = "Grain Amount";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 20.0;
> = 0.35;

uniform float _ChromAb <
    ui_category = "Main Shader";
    ui_label = "Chromatic Aberration";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 20.0;
> = 1.65;

uniform float _Vignette <
    ui_category = "Main Shader";
    ui_label = "Vignette";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 2.0;
> = 0.6;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

// Lens pass entry point.
void FFX_Lens(
    inout float3 Color,
    in float2 HPos,
    in float2 Tex,
    in float GrainScale,
    in float GrainAmount,
    in float ChromAb,
    in float Vignette,
    in float GrainSeed
)
{
    float2 RGMag = FFX_Lens_GetRGMag(ChromAb);
    FFX_Lens_ChromaticAberrationTex ChromaticAberrationTex = FFX_Lens_GetChromaticAberrationTex(Tex, 0.5, RGMag.r, RGMag.g);
    float2 UNormTex = Tex - 0.5;

    // Run Lens
    Color = 1.0;
    Color.r = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, ChromaticAberrationTex.Red).r;
    Color.g = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, ChromaticAberrationTex.Green).g;
    Color.b = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, ChromaticAberrationTex.Blue).b;
    FFX_Lens_ApplyVignette(UNormTex, 0.0, Color, Vignette);
    FFX_Lens_ApplyFilmGrain(HPos, Color, GrainScale, GrainAmount, GrainSeed);
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 OutputColor = 1.0;
    float Seed = _GrainSeed;
    Seed = (_UseTimeSeed) ? Seed + (rcp(1e+3 / _Time) * _GrainSeedSpeed) : Seed;
    FFX_Lens(
        OutputColor.rgb,
        Input.HPos.xy,
        Input.Tex0,
        _GrainScale,
        _GrainAmount,
        _ChromAb,
        _Vignette,
        Seed
    );

    Output = CBlend_OutputChannels(OutputColor.rgb, _CShade_AlphaFactor);
}

technique CShade_Lens
<
    ui_label = "CShade · AMD FidelityFX · Lens";
    ui_tooltip = "AMD FidelityFX Lens.";
>
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
