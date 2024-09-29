
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

#include "cTonemap.fxh"

#if !defined(INCLUDE_CTONEMAP_OUTPUT)
    #define INCLUDE_CTONEMAP_OUTPUT

    uniform int _CShadeTonemapOperator <
        ui_category = "[ Pipeline | Output | Tonemapping ]";
        ui_label = "Tonemap Operator";
        ui_tooltip = "Select a tonemap operator for the output";
        ui_type = "combo";
        ui_items = "None\0Reinhard\0Reinhard Squared\0Standard\0Exponential\0ACES Filmic Curve\0AMD Resolve\0";
    > = 5;

    float3 CTonemap_ApplyOutputTonemap(float3 HDR)
    {
        switch (_CShadeTonemapOperator)
        {
            case 0:
                return HDR;
            case 1:
                return CTonemap_ApplyReinhard(HDR, 1.0);
            case 2:
                return CTonemap_ApplyReinhardSquared(HDR, 0.25);
            case 3:
                return CTonemap_ApplyStandard(HDR);
            case 4:
                return CTonemap_ApplyExponential(HDR);
            case 5:
                return CTonemap_ApplyACES(HDR);
            case 6:
                return CTonemap_ApplyAMDTonemap(HDR);
            default:
                return HDR;
        }
    }

#endif
