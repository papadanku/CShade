
#include "shared/cGraphics.fxh"
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

uniform float _Contrast <
    ui_label = "Contrast";
    ui_type = "slider";
    ui_step = 0.001;
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

float4 PS_CasFilterNoScaling(VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    FFX_CAS_FilterNoScaling(OutputColor.rgb, Input, _Contrast);
    return OutputColor;
}

technique CShade_ImageSharpening
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_CasFilterNoScaling;
    }
}
