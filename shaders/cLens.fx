
#include "shared/cGraphics.fxh"
#include "shared/fidelityfx/cLens.fxh"

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

uniform float _Time < source = "timer"; >;

uniform bool _UseTimeSeed <
    ui_category = "Grain";
    ui_label = "Use Time-Based Seed";
    ui_type = "radio";
> = false;

uniform float _GrainScale <
    ui_category = "Grain";
    ui_label = "Scale";
    ui_type = "slider";
    ui_min = 0.01;
    ui_max = 20.0;
> = 0.01;

uniform float _GrainAmount <
    ui_category = "Grain";
    ui_label = "Amount";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 20.0;
> = 0.7;

uniform float _GrainSeed <
    ui_category = "Grain";
    ui_label = "Seed Offset";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

uniform float _Speed <
    ui_category = "Grain";
    ui_label = "Seed Speed";
    ui_type = "slider";
    ui_min = 0.1;
    ui_max = 1.0;
> = 0.5;

uniform float _ChromAb <
    ui_category = "Chromatic Aberration";
    ui_label = "Intensity";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 20.0;
> = 1.65;

uniform float _Vignette <
    ui_category = "Vignette";
    ui_label = "Intensity";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 2.0;
> = 0.6;

float4 PS_Lens(VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float Seed = _GrainSeed;
    Seed = (_UseTimeSeed) ? Seed + (rcp(1e+3 / _Time) * _Speed) : Seed;
    FFX_Lens(OutputColor.rgb, Input, _GrainScale, _GrainAmount, _ChromAb, _Vignette, Seed);
    return OutputColor;
}

technique CShade_Lens
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Lens;
    }
}
