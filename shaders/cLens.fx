#define CSHADE_LENS

/*
    This shader applies lens-related visual effects, inspired by AMD FidelityFX Lens. It simulates film grain, chromatic aberration, and vignetting, allowing users to control their intensity and characteristics. The film grain can be seeded by time for dynamic patterns, and adjustments are available for grain size, amount, chromatic aberration strength, and vignette intensity.
*/

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
    ui_label = "Use Time for Seed";
    ui_type = "radio";
    ui_tooltip = "When enabled, the grain effect's randomness is influenced by the shader's elapsed time, creating a dynamic, evolving pattern.";
> = true;

uniform float _GrainSeed <
    ui_category = "Main Shader";
    ui_label = "Grain Seed Offset";
    ui_type = "drag";
    ui_tooltip = "Provides an offset to the random seed used for generating film grain, allowing for different grain patterns.";
> = 0.0;

uniform float _GrainSeedSpeed <
    ui_category = "Main Shader";
    ui_label = "Grain Seed Speed";
    ui_max = 1.0;
    ui_min = 0.1;
    ui_type = "slider";
    ui_tooltip = "Controls how quickly the film grain pattern changes over time when 'Enable Time Seed' is active.";
> = 0.5;

uniform float _GrainScale <
    ui_category = "Main Shader";
    ui_label = "Grain Size";
    ui_max = 20.0;
    ui_min = 0.01;
    ui_text = " ";
    ui_type = "slider";
    ui_tooltip = "Adjusts the size of the individual grain particles. Smaller values result in finer grain.";
> = 0.01;

uniform float _GrainAmount <
    ui_category = "Main Shader";
    ui_label = "Grain Intensity";
    ui_max = 20.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Determines the visibility and intensity of the film grain effect.";
> = 0.35;

uniform float _ChromAb <
    ui_category = "Main Shader";
    ui_label = "Chromatic Aberration Strength";
    ui_max = 20.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the strength of chromatic aberration, which creates color fringing around high-contrast edges.";
> = 1.65;

uniform float _Vignette <
    ui_category = "Main Shader";
    ui_label = "Vignette Intensity";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the intensity of the vignette effect, darkening the edges of the screen.";
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
    Color.r = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, ChromaticAberrationTex.Red).r;
    Color.g = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, ChromaticAberrationTex.Green).g;
    Color.b = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, ChromaticAberrationTex.Blue).b;
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
    ui_label = "CShade / AMD FidelityFX / Lens";
    ui_tooltip = "AMD FidelityFX Lens.";
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
