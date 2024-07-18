
#include "../cGraphics.fxh"

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

#if !defined(INCLUDE_FIDELITYFX_CAS)
    #define INCLUDE_FIDELITYFX_CAS

    void FFX_CasFilterNoScaling
    (
        inout float3 FilterShape,
        in VS2PS_Quad Input,
        in float Contrast
    )
    {
        /*
            Load a collection of samples in a 3x3 neighorhood, where e is the current pixel.
            a b
            e
            c d
        */
        float2 Delta = fwidth(Input.Tex0.xy);
        float4 Tex = Input.Tex0.xyxy + (Delta.xyxy * float4(-0.5, -0.5, 0.5, 0.5));
        float3 SampleA = tex2D(CShade_SampleColorTex, Tex.xw).rgb;
        float3 SampleB = tex2D(CShade_SampleColorTex, Tex.zw).rgb;
        float3 SampleC = tex2D(CShade_SampleColorTex, Tex.xy).rgb;
        float3 SampleD = tex2D(CShade_SampleColorTex, Tex.zy).rgb;
        float3 SampleE = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;

        // Get polar min/max
        float3 MinRGB = min(SampleE, min(min(SampleA, SampleB), min(SampleC, SampleD)));
        float3 MaxRGB = max(SampleE, max(max(SampleA, SampleB), max(SampleC, SampleD)));

        // Get needed reciprocal
        float3 ReciprocalMaxRGB = 1.0 / MaxRGB;

        // Amplify
        float3 AmplifyRGB = saturate(min(MinRGB, 2.0 - MaxRGB) * ReciprocalMaxRGB);

        // Shaping amount of sharpening.
        AmplifyRGB *= rsqrt(AmplifyRGB);

        // Filter shape.
        // w w
        //  1 
        // w w 
        float3 Peak = -(1.0 / lerp(8.0, 5.0, Contrast));
        float3 Weight = AmplifyRGB * Peak;
        float3 ReciprocalWeight = 1.0 / (1.0 + (4.0 * Weight));

        FilterShape = SampleE;
        FilterShape += SampleA * Weight;
        FilterShape += SampleB * Weight;
        FilterShape += SampleC * Weight;
        FilterShape += SampleD * Weight;
        FilterShape = saturate(FilterShape * ReciprocalWeight);
    }

#endif