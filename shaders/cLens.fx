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


/*
    [Shader Options]
*/

#include "shared/cColor.fxh"
#include "shared/cShadeHDR.fxh"

// Inject cLens.fxh
#ifndef SHADER_TOGGLE_ABBERATION
    #define SHADER_TOGGLE_ABBERATION 1
#endif
#ifndef SHADER_TOGGLE_VIGNETTE
    #define SHADER_TOGGLE_VIGNETTE 1
#endif
#ifndef SHADER_TOGGLE_GRAIN
    #define SHADER_TOGGLE_GRAIN 1
#endif
#define CLENS_TOGGLE_ABBERATION SHADER_TOGGLE_ABBERATION
#define CLENS_TOGGLE_VIGNETTE SHADER_TOGGLE_VIGNETTE
#define CLENS_TOGGLE_GRAIN SHADER_TOGGLE_GRAIN
#include "shared/cLens.fxh"

// Inject cComposite.fxh
#ifndef SHADER_TOGGLE_GRADING
    #define SHADER_TOGGLE_GRADING 0
#endif
#ifndef SHADER_TOGGLE_TONEMAP
    #define SHADER_TOGGLE_TONEMAP 0
#endif
#ifndef SHADER_TOGGLE_PEAKING
    #define SHADER_TOGGLE_PEAKING 0
#endif
#define CCOMPOSITE_TOGGLE_GRADING SHADER_TOGGLE_GRADING
#define CCOMPOSITE_TOGGLE_TONEMAP SHADER_TOGGLE_TONEMAP
#define CCOMPOSITE_TOGGLE_PEAKING SHADER_TOGGLE_PEAKING
#include "shared/cComposite.fxh"

#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Get backbuffer
    #if CLENS_TOGGLE_ABBERATION
        float2 RGMag = CLens_GetRGMag(_CLens_ChromAb);
        CLens_ChromaticAberrationTex ChromaticAberrationTex = CLens_GetChromaticAberrationTex(Input.Tex0, 0.5, RGMag.r, RGMag.g);

        float3 Color = 1.0;
        Color.r = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, ChromaticAberrationTex.Red).r;
        Color.g = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, ChromaticAberrationTex.Green).g;
        Color.b = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, ChromaticAberrationTex.Blue).b;
    #else
        float3 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0).rgb;
    #endif

    // Apply (optional) vignette
    #if CLENS_TOGGLE_VIGNETTE
        float2 UNormTex = Input.Tex0 - 0.5;
        CLens_ApplyVignette(Color, UNormTex, 0.0, _CLens_Vignette);
    #endif

    // Apply (optional) film grain
    #if CLENS_TOGGLE_GRAIN
        CLens_ApplyFilmGrain(Color, Input.HPos, _CLens_GrainScale, _CLens_GrainAmount, _CLens_GrainSeed);
    #endif

    // Apply color grading
    CComposite_ApplyOutput(Color.rgb);

    // Apply exposure peaking to areas that need it
    CComposite_ApplyExposurePeaking(Color, Input.HPos.xy);

    // Our epic output
    Output = CBlend_OutputChannels(Color, _CShade_AlphaFactor);
}

technique CShade_Lens
<
    ui_label = "CShade / AMD FidelityFX / Lens [+?]";
    ui_tooltip = "Adjustable lens effect with optional color grading.\n\n[+] This shader has optional color grading (SHADER_TOGGLE_GRADING).\n[?] This shader has optional exposure peaking display (SHADER_TOGGLE_PEAKING).";
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
