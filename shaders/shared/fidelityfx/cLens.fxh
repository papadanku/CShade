
#include "../cGraphics.fxh"
#include "../cMath.fxh"

/*
    https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK

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

#if !defined(INCLUDE_FIDELITYFX_LENS)
    #define INCLUDE_FIDELITYFX_LENS

    // Noise function used as basis for film grain effect
    uint3 pcg3d16(uint3 V)
    {
        V = V * 12829u + 47989u;
        V.x += V.y * V.z;
        V.y += V.z * V.x;
        V.z += V.x * V.y;
        V.x += V.y * V.z;
        V.y += V.z * V.x;
        V.z += V.x * V.y;
        V >>= 16u;
        return V;
    }

    // Simplex noise, transforms given position onto triangle grid
    // This logic should be kept at 32-bit floating point precision. 16 bits causes artifacting.
    float2 Simplex(const in float2 P)
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

    float2 toFloat16(uint2 InputValue)
    {
        return float2(InputValue * (1.0 / 65536.0) - 0.5);
    }

    float3 toFloat16(uint3 InputValue)
    {
        return float3(InputValue * (1.0 / 65536.0) - 0.5);
    }

    // Function call to calculate the red and green wavelength/channel sample offset values.
    float2 FfxLensGetRGMag
    (
        float ChromAbIntensity // Intensity constant value for the chromatic aberration effect.
    )
    {
        const float A = 1.5220;
        const float B = 0.00459 * ChromAbIntensity;  // um^2

        const float3 WaveLengthUM = float3(0.612, 0.549, 0.464);
        const float3 IdxRefraction = A + B / WaveLengthUM;
        const float2 RedGreenMagnitude = (IdxRefraction.rg - 1.0) / (IdxRefraction.bb - 1.0);

        // float2 containing the red and green wavelength/channel magnitude values
        return RedGreenMagnitude;
    }

    /// Function call to apply chromatic aberration effect when sampling the Color input texture.
    float3 FfxLensSampleWithChromaticAberration
    (
        int2 Coord, // The input window coordinate [0, widthPixels), [0, heightPixels).
        int2 CenterCoord, // The center window coordinate of the screen.
        float RedMagnitude, //  Magnitude value for the offset calculation of the red wavelength (texture channel).
        float GreenMagnitude // Magnitude value for the offset calculation of the green wavelength (texture channel).
    )
    {
        float2 RedShift = (Coord - CenterCoord) * RedMagnitude + CenterCoord + 0.5;
        RedShift *= ffxReciprocal(2.0 * CenterCoord);
        float2 GreenShift = (Coord - CenterCoord) * GreenMagnitude + CenterCoord + 0.5;
        GreenShift *= ffxReciprocal(2.0 * CenterCoord);

        float Red = FfxLensSampleR(RedShift);
        float Green = FfxLensSampleG(GreenShift);
        float Blue = FfxLensSampleB(Coord * ffxReciprocal(2.0 * CenterCoord));

        return float3(Red, Green, Blue);
    }

    /// Function call to apply film grain effect to inout Color. This call could be skipped entirely as the choice to use the film grain is optional.
    void FfxLensApplyFilmGrain
    (
        int2 Coord, // The input window coordinate [0, widthPixels), [0, heightPixels).
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration function.
        float GrainScaleValue, // Scaling constant value for the grain's noise frequency.
        float GrainAmountValue, // Intensity constant value of the grain effect.
        uint GrainSeedValue // Seed value for the grain noise, for example, to change how the noise functions effect the grain frame to frame.
    )
    {
        float2 RandomNumberFine = toFloat16(pcg3d16(uint3(Coord / (GrainScaleValue / 8), GrainSeedValue)).xy).xy;
        float2 SimplexP = Simplex(Coord / GrainScaleValue + RandomNumberFine);
        const float GrainShape = 3.0;

        float Grain = 1.0 - 2.0 * exp2(-length(SimplexP) * GrainShape);

        Color += Grain * min(Color, 1.0 - Color) * GrainAmountValue;
    }

    /// Function call to apply vignette effect to inout Color. This call could be skipped entirely as the choice to use the vignette is optional.
    void FfxLensApplyVignette
    (
        int2 Coord, // The input window coordinate [0, widthPixels), [0, heightPixels).
        int2 CenterCoord, // The center window coordinate of the screen.
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration and film grain functions.
        float VignetteAmount // Intensity constant value of the vignette effect.
    )
    {
        float2 VignetteMask = float2(0.0, 0.0);
        float2 CoordFromCenter = abs(Coord - CenterCoord) / float2(CenterCoord);

        const float piOver4 = CMath_GetPi() * 0.25;
        VignetteMask = cos(CoordFromCenter * VignetteAmount * piOver4);
        VignetteMask = VignetteMask * VignetteMask;
        VignetteMask = VignetteMask * VignetteMask;

        Color *= clamp(VignetteMask.x * VignetteMask.y, 0.0, 1.0);
    }

    #endif

    /// Lens pass entry point.
    ///
    /// @param Gtid Thread index within thread group (SV_GroupThreadID).
    /// @param Gidx Group index of thread (SV_GroupID).
    /// @ingroup FfxGPULens
    void FfxLens(FfxUInt32 Gtid, uint2 Gidx)
    {
        // Do remapping of local xy in workgroup for a more PS-like swizzle pattern.
        // Assumes 64,1,1 threadgroup size and an 8x8 api dispatch
        int2 Coord = int2(ffxRemapForWaveReduction(Gtid) + uint2(Gidx.x << 3u, Gidx.y << 3u));

        // Run Lens
        float2 RGMag = FfxLensGetRGMag(ChromAb());
        float3 Color = FfxLensSampleWithChromaticAberration(Coord, int2(Center()), RGMag.r, RGMag.g);
        FfxLensApplyVignette(Coord, int2(Center()), Color, Vignette());
        FfxLensApplyFilmGrain(Coord, Color, GrainScale(), GrainAmount(), GrainSeed());
    }

#endif