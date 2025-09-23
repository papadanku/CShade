
/*
    The MIT License (MIT)

    Copyright (c) 2015 Microsoft

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

#include "cColor.fxh"

#if !defined(INCLUDE_TONEMAP)
    #define INCLUDE_TONEMAP

    /*
        The Reinhard tone operator. Typically, the value of K is 1.0, but you can adjust exposure by 1/K.
        I.e. CTonemap_ApplyReinhard(x, 0.5) == CTonemap_ApplyReinhard(x * 2.0, 1.0)
    */

    float3 CTonemap_ApplyReinhard(float3 HDR, float K)
    {
        return HDR / (HDR + K);
    }

    // The inverse of Reinhard
    float3 CTonemap_ApplyInverseReinhard(float3 SDR, float K)
    {
        return K * SDR / (K - SDR);
    }

    /*
        Reinhard-Squared

        This has some nice properties that improve on basic Reinhard.  Firstly, it has a "toe"--that nice,
        parabolic upswing that enhances contrast and color saturation in darks.  Secondly, it has a long
        shoulder giving greater detail in highlights and taking longer to desaturate.  It's invertible, scales
        to HDR displays, and is easy to control.

        The default constant of 0.25 was chosen for two reasons.  It maps closely to the effect of Reinhard
        with a constant of 1.0.  And with a constant of 0.25, there is an inflection point at 0.25 where the
        curve touches the line y=x and then begins the shoulder.

        Note:  If you are currently using ACES and you pre-scale by 0.6, then k=0.30 looks nice as an alternative
        without any other adjustments.
    */

    float3 CTonemap_ApplyReinhardSquared(float3 HDR, float K)
    {
        float3 reinhard = HDR / (HDR + K);
        return reinhard * reinhard;
    }

    float3 CTonemap_ApplyInverseReinhardSquared(float3 SDR, float K)
    {
        return K * (SDR + sqrt(SDR)) / (1.0 - SDR);
    }

    /*
        https://gpuopen.com/learn/optimized-reversible-tonemapper-for-resolve/
    */

    // Apply this to tonemap linear HDR color "HDR" after a sample is fetched in the resolve.
    // Note "HDR" 1.0 maps to the expected limit of low-dynamic-range monitor output.
    float3 CTonemap_ApplyAMDTonemap(float3 HDR)
    {
        return HDR / (max(max(HDR.r, HDR.g), HDR.b) + 1.0);
    }

    // When the filter kernel is a weighted sum of fetched colors,
    // it is more optimal to fold the weighting into the tonemap operation.
    float3 CTonemap_ApplyAMDTonemapWithWeight(float3 HDR, float Weight)
    {
        return HDR * (Weight / (max(max(HDR.r, HDR.g), HDR.b) + 1.0));
    }

    // Apply this to restore the linear HDR color before writing out the result of the resolve.
    float3 CTonemap_ApplyInverseAMDTonemap(float3 HDR)
    {
        return HDR / (1.0 - max(max(HDR.r, HDR.g), HDR.b));
    }

    float3 CTonemap_ApplyTonemap(float3 HDR, int Tonemapper)
    {
        switch (Tonemapper)
        {
            case 0:
                return HDR;
            case 1:
                return CTonemap_ApplyReinhard(HDR, 1.0);
            case 2:
                return CTonemap_ApplyReinhardSquared(HDR, 0.25);
            case 3:
                return CTonemap_ApplyAMDTonemap(HDR);
            case 4:
                return CColor_EncodeLogC(HDR);
            default:
                return HDR;
        }
    }

    float4 CTonemap_ApplyInverseTonemap(float4 SDR, int Tonemapper)
    {
        switch (Tonemapper)
        {
            case 0:
                SDR.rgb = SDR.rgb;
                break;
            case 1:
                SDR.rgb = CTonemap_ApplyInverseReinhard(SDR.rgb, 1.0);
                break;
            case 2:
                SDR.rgb = CTonemap_ApplyInverseReinhardSquared(SDR.rgb, 0.25);
                break;
            case 3:
                SDR.rgb = CTonemap_ApplyInverseAMDTonemap(SDR.rgb);
                break;
            case 4:
                SDR.rgb = CColor_DecodeLogC(SDR.rgb);
                break;
            default:
                SDR.rgb = SDR.rgb;
                break;
        }

        return SDR;
    }

#endif
