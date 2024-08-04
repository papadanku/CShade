
#include "shared/cShade.fxh"
#include "shared/fidelityfx/cCas.fxh"

/*
    Bilinear modification of AMD's CAS algorithm.

    Source: https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/sdk/include/FidelityFX/gpu/cas/ffx_cas.h

    This file is part of the FidelityFX SDK.

    Copyright (C) 2024 Advanced Micro Devices, Inc.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files(the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

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

uniform int _Detection <
    ui_label = "Detection Mode";
    ui_type = "combo";
    ui_items = "Color\0Luminance (Average)\0Luminance (Max)\0";
> = 0;

uniform int _Kernel <
    ui_label = "Kernel Shape";
    ui_type = "combo";
    ui_items = "CAS: 3x3 Box\0CAS: Diamond\0CShade: Bilinear Diamond\0";
> = 1;

uniform float _Contrast <
    ui_label = "Contrast";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

uniform float _Sharpening <
    ui_label = "Sharpening";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

uniform int _DisplayMode <
    ui_label = "Display Mode";
    ui_type = "radio";
    ui_items = "Output\0Mask\0";
> = 0;

float4 PS_CasFilterNoScaling(CShade_VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float4 OutputMask = 1.0;
    FFX_CAS_FilterNoScaling(
        OutputColor,
        OutputMask,
        Input,
        _Detection,
        _Kernel,
        _Contrast,
        _Sharpening
    );

    if (_DisplayMode == 1)
    {
        return OutputMask;
    }

    return OutputColor;
}

technique CShade_ImageSharpening
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CasFilterNoScaling;
    }
}
