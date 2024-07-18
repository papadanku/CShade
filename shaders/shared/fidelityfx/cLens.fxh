
#include "../cGraphics.fxh"
#include "../cMath.fxh"
#include "../cProcedural.fxh"

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

    // Simplex noise, transforms given position onto triangle grid
    // This logic should be kept at 32-bit floating point precision. 16 bits causes artifacting.
    float2 FFX_Lens_Simplex(const in float2 P)
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
    float2 FFX_Lens_GetRGMag
    (
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

    /// Function call to apply chromatic aberration effect when sampling the Color input texture.
    float3 FFX_Lens_SampleWithChromaticAberration
    (
        VS2PS_Quad VS, // The input.HPos window coordinate [0, widthPixels), [0, heightPixels).
        float2 CenterCoord, // The center window coordinate of the screen.
        float RedMagnitude, // Magnitude value for the offset calculation of the red wavelength (texture channel).
        float GreenMagnitude // Magnitude value for the offset calculation of the green wavelength (texture channel).
    )
    {
        float2 RedShift = (VS.HPos.xy - CenterCoord) * RedMagnitude + CenterCoord + 0.5;
        RedShift *= (1.0 / (2.0 * CenterCoord));
        float2 GreenShift = (VS.HPos.xy - CenterCoord) * GreenMagnitude + CenterCoord + 0.5;
        GreenShift *= (1.0 / (2.0 * CenterCoord));
        float2 BlueShift = VS.Tex0;

        float3 RGB = 0.0;
        RGB.r = tex2D(CShade_SampleColorTex, RedShift).r;
        RGB.g = tex2D(CShade_SampleColorTex, GreenShift).g;
        RGB.b = tex2D(CShade_SampleColorTex, BlueShift).b;

        return RGB;
    }

    /// Function call to apply film grain effect to inout Color. This call could be skipped entirely as the choice to use the film grain is optional.
    void FFX_Lens_ApplyFilmGrain
    (
        in VS2PS_Quad VS, // The input window coordinate [0, widthPixels), [0, heightPixels).
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration function.
        float GrainScaleValue, // Scaling constant value for the grain's noise frequency.
        float GrainAmountValue, // Intensity constant value of the grain effect.
        float GrainSeedValue // Seed value for the grain noise, for example, to change how the noise functions effect the grain frame to frame.
    )
    {
        float2 RandomNumberFine = ToFloat16(CProcedural_GetHash2(VS.Tex0.xy, 0.0));
        float2 Coords = (VS.Tex0.xy * 2.0 - 1.0) * CGraphics_GetScreenSizeFromTex(VS.Tex0.xy);
        float2 GradientN = GetGradientNoise2((Coords.xy / GrainScaleValue) / 16.0, GrainSeedValue, true) * 0.5;
        const float GrainShape = 3.0;

        float Grain = 1.0 - 2.0 * exp2(-length(GradientN) * GrainShape);

        Color += Grain * min(Color, 1.0 - Color) * GrainAmountValue;
    }

    /// Function call to apply vignette effect to inout Color. This call could be skipped entirely as the choice to use the vignette is optional.
    void FFX_Lens_ApplyVignette
    (
        float2 Coord, // The input window coordinate [0, widthPixels), [0, heightPixels).
        float2 CenterCoord, // The center window coordinate of the screen.
        inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration and film grain functions.
        float VignetteAmount // Intensity constant value of the vignette effect.
    )
    {
        float2 VignetteMask = float2(0.0, 0.0);
        float2 CoordFromCenter = abs(Coord - CenterCoord) / float2(CenterCoord);

        const float PiOver4 = CMath_GetPi() * 0.25;
        VignetteMask = cos(CoordFromCenter * VignetteAmount * PiOver4);
        VignetteMask = VignetteMask * VignetteMask;
        VignetteMask = VignetteMask * VignetteMask;

        Color *= clamp(VignetteMask.x * VignetteMask.y, 0.0, 1.0);
    }

    /// Lens pass entry point.
    void FFX_Lens
    (
        inout float3 Color,
        in VS2PS_Quad VS,
        in float GrainScale,
        in float GrainAmount,
        in float ChromAb,
        in float Vignette,
        in float GrainSeed
        )
    {
        // Run Lens
        float2 RGMag = FFX_Lens_GetRGMag(ChromAb);
        float2 Center = CGraphics_GetScreenSizeFromTex(VS.Tex0.xy) / 2.0;
        Color = FFX_Lens_SampleWithChromaticAberration(VS, Center, RGMag.r, RGMag.g);
        FFX_Lens_ApplyVignette(VS.Tex0.xy, 0.5, Color, Vignette);
        FFX_Lens_ApplyFilmGrain(VS, Color, GrainScale, GrainAmount, GrainSeed);
    }

#endif