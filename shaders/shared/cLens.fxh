
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
    This header file provides a set of functions for applying lens-related visual effects, building upon AMD's FidelityFX Lens algorithm. It primarily focuses on simulating film grain, chromatic aberration, and vignetting. The file includes functions to calculate chromatic aberration offsets, apply film grain using simplex noise, and generate a vignette mask. This header enables the creation of realistic or stylized camera lens imperfections within shaders.

    Abstracted Preprocessor Definitions: CSHADE_APPLY_ABBERATION, CSHADE_APPLY_GRAIN, CSHADE_APPLY_VIGNETTE
*/

#include "cMath.fxh"

#if !defined(CSHADE_FIDELITYFX_LENS)
    #define CSHADE_FIDELITYFX_LENS

    #ifndef CSHADE_APPLY_ABBERATION
        #define CSHADE_APPLY_ABBERATION 0
    #endif

    #ifndef CSHADE_APPLY_GRAIN
        #define CSHADE_APPLY_GRAIN 0
    #endif

    #ifndef CSHADE_APPLY_VIGNETTE
        #define CSHADE_APPLY_VIGNETTE 0
    #endif

    #if CSHADE_APPLY_ABBERATION
        uniform float _CLens_ChromAb <
            ui_category = "Output / Lens";
            ui_text = "CHROMATIC ABBERATION";
            ui_label = "Chromatic Aberration Strength";
            ui_max = 20.0;
            ui_min = 0.0;
            ui_type = "slider";
            ui_tooltip = "Controls the strength of chromatic aberration, which creates color fringing around high-contrast edges.";
        > = 1.65;
    #endif

    #if CSHADE_APPLY_VIGNETTE
        uniform float _CLens_Vignette <
            ui_category = "Output / Lens";
            ui_text = "VIGNETTE";
            ui_label = "Vignette Intensity";
            ui_max = 2.0;
            ui_min = 0.0;
            ui_type = "slider";
            ui_tooltip = "Adjusts the intensity of the vignette effect, darkening the edges of the screen.";
        > = 0.6;
    #endif

    #if CSHADE_APPLY_GRAIN
        uniform float _CLens_Time < source = "timer"; >;

        uniform bool _CLens_UseTimeSeed <
            ui_category = "Output / Lens";
            ui_text = "FILM GRAIN";
            ui_label = "Use Time for Seed";
            ui_type = "radio";
            ui_tooltip = "When enabled, the grain effect's randomness is influenced by the shader's elapsed time, creating a dynamic, evolving pattern.";
        > = true;

        uniform float _CLens_GrainSeed <
            ui_category = "Output / Lens";
            ui_label = "Grain Seed Offset";
            ui_type = "drag";
            ui_tooltip = "Provides an offset to the random seed used for generating film grain, allowing for different grain patterns.";
        > = 0.0;

        uniform float _CLens_GrainSeedSpeed <
            ui_category = "Output / Lens";
            ui_label = "Grain Seed Speed";
            ui_max = 1.0;
            ui_min = 0.1;
            ui_type = "slider";
            ui_tooltip = "Controls how quickly the film grain pattern changes over time when 'Enable Time Seed' is active.";
        > = 0.5;

        uniform float _CLens_GrainScale <
            ui_category = "Output / Lens";
            ui_label = "Grain Size";
            ui_max = 20.0;
            ui_min = 0.01;
            ui_type = "slider";
            ui_tooltip = "Adjusts the size of the individual grain particles. Smaller values result in finer grain.";
        > = 0.01;

        uniform float _CLens_GrainAmount <
            ui_category = "Output / Lens";
            ui_label = "Grain Intensity";
            ui_max = 20.0;
            ui_min = 0.0;
            ui_type = "slider";
            ui_tooltip = "Determines the visibility and intensity of the film grain effect.";
        > = 0.35;
    #endif

    // Simplex noise, transforms given position onto triangle grid
    // This logic should be kept at 32-bit floating point precision. 16 bits causes artifacting.
    float2 CLens_Simplex(float2 P)
    {
        // Skew and unskew factors are a bit hairy for 2D, so define them as constants
        const float F2 = (sqrt(3.0) - 1.0) / 2.0;  // 0.36602540378
        const float G2 = (3.0 - sqrt(3.0)) / 6.0;  // 0.2113248654

        // Skew the (x,y) space to determine which cell of 2 simplices we're in
        float U = (P.x + P.y) * F2;
        float2 Pi = round(P + U);
        float V = (Pi.x + Pi.y) * G2;
        float2 P0 = Pi - V; // Unskew the cell origin back to (x,y) space
        float2 Pf0 = P - P0; // The x,y distances from the cell origin

        return float2(Pf0);
    }

    float2 CLens_ToFloat16(uint2 InputValue)
    {
        return float2(InputValue * (1.0 / 65536.0) - 0.5);
    }

    // Function call to calculate the red and green wavelength/channel sample offset values.
    float2 CLens_GetRGMag(
        float ChromAbIntensity // Intensity constant value for the chromatic aberration effect.
    )
    {
        const float A = 1.5220;
        const float B = 0.00459 * ChromAbIntensity; // um^2

        const float3 WaveLengthUM = float3(0.612, 0.549, 0.464);
        const float3 IdxRefraction = A + B / WaveLengthUM;
        const float2 RedGreenMagnitude = (IdxRefraction.rg - 1.0) / (IdxRefraction.bb - 1.0);

        // float2 containing the red and green wavelength/channel magnitude values
        return RedGreenMagnitude;
    }

    struct CLens_ChromaticAberrationTex
    {
        float2 Red;
        float2 Green;
        float2 Blue;
    };

    CLens_ChromaticAberrationTex CLens_GetChromaticAberrationTex(
        float2 Tex, // The input window coordinate [0, 1), [0, 1).
        float2 CenterCoord, // The center window coordinate of the screen.
        float RedMagnitude, // Magnitude value for the offset calculation of the red wavelength (texture channel).
        float GreenMagnitude // Magnitude value for the offset calculation of the green wavelength (texture channel).
    )
    {
        CLens_ChromaticAberrationTex Output;

        float2 Delta = fwidth(Tex);
        Output.Red = ((Tex - CenterCoord) * RedMagnitude) + (Delta * 0.5);
        Output.Red += CenterCoord;
        Output.Green = ((Tex - CenterCoord) * GreenMagnitude) + (Delta * 0.5);
        Output.Green += CenterCoord;
        Output.Blue = Tex;

        return Output;
    }

    // Function call to apply film grain effect to inout Color. This call could be skipped entirely as the choice to use the film grain is optional.
    void CLens_ApplyFilmGrain(
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration function.
        in float2 Pos, // The input window coordinate [0, Width), [0, Height).
        in float GrainScaleValue, // Scaling constant value for the grain's noise frequency.
        in float GrainAmountValue, // Intensity constant value of the grain effect.
        in float GrainSeedValue // Seed value for the grain noise, for example, to change how the noise functions effect the grain frame to frame.
    )
    {
        float2 RandomNumberFine = CMath_GetHash_FLT2(Pos, GrainSeedValue);
        float2 GradientN = CLens_Simplex((Pos / GrainScaleValue) + RandomNumberFine);

        const float GrainShape = 3.0;
        float Grain = exp2(-length(GradientN) * GrainShape);
        Grain = 1.0 - 2.0 * Grain;
        Color += Grain * min(Color, 1.0 - Color) * GrainAmountValue;
    }

    float CLens_GetVignetteMask(
        in float2 Coord, // The input window coordinate [-0.5, 0.5), [-0.5, 0.5).
        in float2 CenterCoord, // The center window coordinate of the screen.
        in float VignetteAmount // Intensity constant value of the vignette effect.
    )
    {
        float2 VignetteMask = 0.0;
        float2 CoordFromCenter = abs(Coord - CenterCoord);

        const float Pi = CMath_GetPi();
        const float PiOver2 = Pi * 0.5;
        const float PiOver4 = Pi * 0.25;
        VignetteMask = cos(min(CoordFromCenter * VignetteAmount * PiOver4, PiOver2));
        VignetteMask *= VignetteMask;
        VignetteMask *= VignetteMask;

        return clamp(VignetteMask.x * VignetteMask.y, 0.0, 1.0);
    }

    // Function call to apply vignette effect to inout Color. This call could be skipped entirely as the choice to use the vignette is optional.
    void CLens_ApplyVignette(
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration and film grain functions.
        in float2 Coord, // The input window coordinate [-0.5, 0.5), [-0.5, 0.5).
        in float2 CenterCoord, // The center window coordinate of the screen.
        in float VignetteAmount // Intensity constant value of the vignette effect.
    )
    {
        float VignetteMask = CLens_GetVignetteMask(Coord, CenterCoord, VignetteAmount);
        Color *= VignetteMask;
    }

    // Lens pass entry point.
    void CLens(
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
        float2 RGMag = CLens_GetRGMag(ChromAb);
        CLens_ChromaticAberrationTex ChromaticAberrationTex = CLens_GetChromaticAberrationTex(Tex, 0.5, RGMag.r, RGMag.g);
        float2 UNormTex = Tex - 0.5;

        // Run Lens
        Color.r = tex2D(CShade_SampleColorTex, ChromaticAberrationTex.Red).r;
        Color.g = tex2D(CShade_SampleColorTex, ChromaticAberrationTex.Green).g;
        Color.b = tex2D(CShade_SampleColorTex, ChromaticAberrationTex.Blue).b;
        CLens_ApplyVignette(Color, UNormTex, 0.0, Vignette);
        CLens_ApplyFilmGrain(Color, HPos, GrainScale, GrainAmount, GrainSeed);
    }

#endif
