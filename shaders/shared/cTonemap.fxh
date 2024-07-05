
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

#if !defined(INCLUDE_TONEMAP)
    #define INCLUDE_TONEMAP

    /*
        The Reinhard tone operator. Typically, the value of K is 1.0, but you can adjust exposure by 1/K.
        I.e. ApplyReinhardTonemap(x, 0.5) == ApplyReinhardTonemap(x * 2.0, 1.0)
    */

    float3 ApplyReinhardTonemap(float3 HDR, float K)
    {
        return HDR / (HDR + K);
    }

    // The inverse of Reinhard
    float3 ApplyInverseReinhardTonemap(float3 SDR, float K)
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

    float3 ApplyReinhardSquaredTonemap(float3 HDR, float K)
    {
        float3 reinhard = HDR / (HDR + K);
        return reinhard * reinhard;
    }

    float3 ApplyInverseReinhardSquaredTonemap(float3 SDR, float K)
    {
        return K * (SDR + sqrt(SDR)) / (1.0 - SDR);
    }

    /*
        This is the new tone operator. It resembles ACES in many ways, but it is simpler to evaluate with ALU. One advantage it has over Reinhard-Squared is that the shoulder goes to white more quickly and gives more overall brightness and contrast to the image.
    */

    float3 ApplyStandardTonemap(float3 HDR)
    {
        return ApplyReinhardTonemap(HDR * sqrt(HDR), sqrt(4.0 / 27.0));
    }

    float3 ApplyInverseStandardTonemap(float3 SDR)
    {
        return pow(ApplyInverseReinhardTonemap(SDR, sqrt(4.0 / 27.0)), 2.0 / 3.0);
    }

    /*
        Standard (Old)

        This is the old tone operator first used in HemiEngine and then MiniEngine. It's simplistic, efficient,
        invertible, and gives nice results, but it has no toe, and the shoulder goes to white fairly quickly.

        Note that I removed the distinction between tone mapping RGB and tone mapping Luma. Philosophically, I
        agree with the idea of trying to remap brightness to displayable values while preserving hue. But you
        run into problems where one or more color channels end up brighter than 1.0 and get clipped.
    */

    float3 ApplyExponentialTonemap(float3 HDR)
    {
        return 1.0 - exp2(-HDR);
    }

    float3 ApplyInverseExponentialTonemap(float3 SDR)
    {
        return -log2(max(1e-6, 1.0 - SDR));
    }

    /*
        ACES: The next generation of filmic tone operators.
    */

    float3 ApplyToneMapACES(float3 HDR)
    {
        const float A = 2.51;
        const float B = 0.03;
        const float C = 2.43;
        const float D = 0.59;
        const float E = 0.14;
        return saturate((HDR * (A * HDR + B)) / (HDR * (C * HDR + D) + E));
    }

    float3 ApplyInverseToneMapACES(float3 SDR)
    {
        const float A = 2.51;
        const float B = 0.03;
        const float C = 2.43;
        const float D = 0.59;
        const float E = 0.14;
        return 0.5 * (D * SDR - sqrt(((D*D - 4.0*C*E) * SDR + 4.0*A*E-2.0*B*D) * SDR + B*B) - B) / (A - C * SDR);
    }

    uniform int _CShadeTonemapOperator <
        ui_category = "Output: Tonemapping";
        ui_label = "Tonemap Operator";
        ui_tooltip = "Select a tonemap operator for the output";
        ui_type = "combo";
        ui_items = "None\0Reinhard\0Reinhard Squared\0Standard\0Exponential\0ACES Filmic Approximation\0";
    > = 0;

    float3 ApplyTonemap(float3 HDR)
    {
        switch (_CShadeTonemapOperator)
        {
            case 0:
                return HDR;
            case 1:
                return ApplyReinhardTonemap(HDR, 1.0);
            case 2:
                return ApplyReinhardSquaredTonemap(HDR, 0.25);
            case 3:
                return ApplyStandardTonemap(HDR);
            case 4:
                return ApplyExponentialTonemap(HDR);
            case 5:
                return ApplyToneMapACES(HDR);
            default:
            	return HDR;
        }
    }

#endif
