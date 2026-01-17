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

/* Shader Options */

#include "shared/cColor.fxh"

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 1 
#include "shared/cShade.fxh"

/* Pixel Shaders */

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Get backbuffer
    #if CSHADE_APPLY_ABBERATION
        float2 RGMag = CLens_GetRGMag(_CLens_ChromAb);
        CLens_ChromaticAberrationTex ChromaticAberrationTex = CLens_GetChromaticAberrationTex(Input.Tex0, 0.5, RGMag.r, RGMag.g);

        float3 Color = 1.0;
        Color.r = tex2D(CShade_SampleColorTex, ChromaticAberrationTex.Red).r;
        Color.g = tex2D(CShade_SampleColorTex, ChromaticAberrationTex.Green).g;
        Color.b = tex2D(CShade_SampleColorTex, ChromaticAberrationTex.Blue).b;
    #else
        float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    #endif

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Color, _CShade_AlphaFactor);
    #else
        Output = float4(Color, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_Lens
<
    ui_label = "CShade | Lens";
    ui_tooltip = "Adjustable lens effect with optional color grading.";
>
{
    pass Lens
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
