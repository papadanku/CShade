
#include "../cShade.fxh"
#include "../cColor.fxh"

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

#if !defined(INCLIDE_FFX_CAS)
    #define INCLIDE_FFX_CAS

    void FFX_CAS_FilterNoScaling(
        inout float4 FilterShape,
        inout float4 FilterMask,
        in float2 Tex,
        in float2 Delta,
        in int Detection,
        in int Kernel,
        in float Contrast
    )
    {
        /*
            Load a collection of samples in a 3x3 neighorhood, where e is the current pixel.
            5 3 6 |   3   | 1 3
            1 0 2 | 1 0 2 |  0
            7 4 8 |   4   | 2 4
        */

        // Select kernel sample
        float4 TexArray[3];
        float4 Sample[9];
        switch (Kernel)
        {
            case 0:
                TexArray[0] = Tex.xyxy + (Delta.xyxy * float4(-1.0, 0.0, 1.0, 0.0));
                TexArray[1] = Tex.xyxy + (Delta.xyxy * float4(0.0, -1.0, 0.0, 1.0));
                TexArray[2] = Tex.xyxy + (Delta.xyxy * float4(-1.0, -1.0, 1.0, 1.0));
                Sample[0] = tex2D(CShade_SampleColorTex, Tex);
                Sample[1] = tex2D(CShade_SampleColorTex, TexArray[0].xy);
                Sample[2] = tex2D(CShade_SampleColorTex, TexArray[0].zw);
                Sample[3] = tex2D(CShade_SampleColorTex, TexArray[1].xy);
                Sample[4] = tex2D(CShade_SampleColorTex, TexArray[1].zw);
                Sample[5] = tex2D(CShade_SampleColorTex, TexArray[2].xw);
                Sample[6] = tex2D(CShade_SampleColorTex, TexArray[2].zw);
                Sample[7] = tex2D(CShade_SampleColorTex, TexArray[2].xy);
                Sample[8] = tex2D(CShade_SampleColorTex, TexArray[2].zy);
                break;
            case 1:
                TexArray[0] = Tex.xyxy + (Delta.xyxy * float4(-1.0, 0.0, 1.0, 0.0));
                TexArray[1] = Tex.xyxy + (Delta.xyxy * float4(0.0, -1.0, 0.0, 1.0));
                Sample[0] = tex2D(CShade_SampleColorTex, Tex);
                Sample[1] = tex2D(CShade_SampleColorTex, TexArray[0].xy);
                Sample[2] = tex2D(CShade_SampleColorTex, TexArray[0].zw);
                Sample[3] = tex2D(CShade_SampleColorTex, TexArray[1].xy);
                Sample[4] = tex2D(CShade_SampleColorTex, TexArray[1].zw);
                break;
            case 2:
                TexArray[0] = Tex.xyxy + (Delta.xyxy * float4(-0.5, -0.5, 0.5, 0.5));
                Sample[0] = tex2D(CShade_SampleColorTex, Tex);
                Sample[1] = tex2D(CShade_SampleColorTex, TexArray[0].xw);
                Sample[2] = tex2D(CShade_SampleColorTex, TexArray[0].zw);
                Sample[3] = tex2D(CShade_SampleColorTex, TexArray[0].xy);
                Sample[4] = tex2D(CShade_SampleColorTex, TexArray[0].zy);
                break;
            default:
                break;
        }

        // Get polar min/max
        float4 MinRGB = min(Sample[0], min(min(Sample[1], Sample[2]), min(Sample[3], Sample[4])));
        float4 MaxRGB = max(Sample[0], max(max(Sample[1], Sample[2]), max(Sample[3], Sample[4])));

        if (Kernel == 0)
        {
            MinRGB = min(MinRGB, min(min(Sample[5], Sample[6]), min(Sample[7], Sample[8])));
            MaxRGB = max(MaxRGB, max(max(Sample[5], Sample[6]), max(Sample[7], Sample[8])));
        }

        // Get needed reciprocal
        float4 ReciprocalMaxRGB = 1.0 / MaxRGB;

        // Amplify
        float4 AmplifyRGB = saturate(min(MinRGB, 2.0 - MaxRGB) * ReciprocalMaxRGB);

        // Optional grayscale
        switch (Detection)
        {
            case 1:
                AmplifyRGB = CColor_GetLuma(AmplifyRGB.rgb, 0);
                break;
            case 2:
                AmplifyRGB = CColor_GetLuma(AmplifyRGB.rgb, 3);
                break;
        }

        // Shaping amount of sharpening.
        AmplifyRGB *= rsqrt(AmplifyRGB);

        /* Filter shape.
              w   |   w   | w w
            w 1 w | w 1 w |  1
              w   |   w   | w w
        */
        float4 Peak = -(1.0 / lerp(8.0, 5.0, Contrast));
        float4 Weight = AmplifyRGB * Peak;
        float4 ReciprocalWeight = 1.0 / (1.0 + (4.0 * Weight));

        FilterShape = Sample[0];
        FilterShape += Sample[1] * Weight;
        FilterShape += Sample[2] * Weight;
        FilterShape += Sample[3] * Weight;
        FilterShape += Sample[4] * Weight;
        FilterShape = saturate(FilterShape * ReciprocalWeight);

        FilterMask = AmplifyRGB;
    }

#endif