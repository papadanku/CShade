
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
#include "shared/cProcedural.fxh"

#if !defined(INCLUDE_FIDELITYFX_LENS)
    #define INCLUDE_FIDELITYFX_LENS
    // Simplex noise, transforms given position onto triangle grid
    // This logic should be kept at 32-bit floating point precision. 16 bits causes artifacting.
    float2 FFX_Lens_Simplex(float2 P)
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

    float2 ToFloat16(uint2 InputValue)
    {
        return float2(InputValue * (1.0 / 65536.0) - 0.5);
    }

    // Function call to calculate the red and green wavelength/channel sample offset values.
    float2 FFX_Lens_GetRGMag(
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

    struct FFX_Lens_ChromaticAberrationTex
    {
        float2 Red;
        float2 Green;
        float2 Blue;
    };

    FFX_Lens_ChromaticAberrationTex FFX_Lens_GetChromaticAberrationTex(
        float2 Tex, // The input window coordinate [0, 1), [0, 1).
        float2 CenterCoord, // The center window coordinate of the screen.
        float RedMagnitude, // Magnitude value for the offset calculation of the red wavelength (texture channel).
        float GreenMagnitude // Magnitude value for the offset calculation of the green wavelength (texture channel).
    )
    {
        FFX_Lens_ChromaticAberrationTex Output;

        float2 Delta = fwidth(Tex);
        Output.Red = ((Tex - CenterCoord) * RedMagnitude) + (Delta * 0.5);
        Output.Red += CenterCoord;
        Output.Green = ((Tex - CenterCoord) * GreenMagnitude) + (Delta * 0.5);
        Output.Green += CenterCoord;
        Output.Blue = Tex;

        return Output;
    }

    // Function call to apply film grain effect to inout Color. This call could be skipped entirely as the choice to use the film grain is optional.
    void FFX_Lens_ApplyFilmGrain(
        in float2 Pos, // The input window coordinate [0, Width), [0, Height).
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration function.
        in float GrainScaleValue, // Scaling constant value for the grain's noise frequency.
        in float GrainAmountValue, // Intensity constant value of the grain effect.
        in float GrainSeedValue // Seed value for the grain noise, for example, to change how the noise functions effect the grain frame to frame.
    )
    {
        float2 RandomNumberFine = CProcedural_GetHash2(Pos, GrainSeedValue);
        float2 GradientN = FFX_Lens_Simplex((Pos / GrainScaleValue) + RandomNumberFine);

        const float GrainShape = 3.0;
        float Grain = exp2(-length(GradientN) * GrainShape);
        Grain = 1.0 - 2.0 * Grain;
        Color += Grain * min(Color, 1.0 - Color) * GrainAmountValue;
    }

    float FFX_Lens_GetVignetteMask(
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
    void FFX_Lens_ApplyVignette(
        in float2 Coord, // The input window coordinate [-0.5, 0.5), [-0.5, 0.5).
        in float2 CenterCoord, // The center window coordinate of the screen.
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration and film grain functions.
        in float VignetteAmount // Intensity constant value of the vignette effect.
    )
    {
        float VignetteMask = FFX_Lens_GetVignetteMask(Coord, CenterCoord, VignetteAmount);
        Color *= VignetteMask;
    }

#endif
