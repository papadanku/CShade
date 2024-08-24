
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
    ui_label = "Enable Time-Based Seed";
    ui_type = "radio";
> = true;

uniform float _GrainSeed <
    ui_label = "Seed Offset";
    ui_type = "drag";
> = 0.0;

uniform float _GrainSeedSpeed <
    ui_label = "Seed Speed";
    ui_type = "slider";
    ui_min = 0.1;
    ui_max = 1.0;
> = 0.5;

uniform int _GrainType <
    ui_label = "Grain Type";
    ui_type = "combo";
    ui_items = "Single-Channel\0Multi-Channel\0";
> = 0;

uniform float _GrainScale <
    ui_category = "Grain";
    ui_label = "Grain Scale";
    ui_type = "slider";
    ui_min = 0.01;
    ui_max = 1.0;
> = 0.01;

uniform float _GrainAmount <
    ui_label = "Grain Amount";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.35;

uniform float _ChromAb <
    ui_label = "Chromatic Aberration";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 20.0;
> = 1.65;

uniform float _Vignette <
    ui_label = "Vignette";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 2.0;
> = 0.6;

#include "shared/fidelityfx/cLens.fxh"
#include "shared/cShade.fxh"
#include "shared/cBlend.fxh"

float4 PS_Lens(CShade_VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float Seed = _GrainSeed;
    Seed = (_UseTimeSeed) ? Seed + (rcp(1e+3 / _Time) * _GrainSeedSpeed) : Seed;
    FFX_Lens(
        OutputColor.rgb,
        CShade_SampleColorTex,
        Input.HPos.xy,
        Input.Tex0,
        _GrainType,
        _GrainScale,
        _GrainAmount,
        _ChromAb,
        _Vignette,
        Seed
    );
    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_Lens
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Lens;
    }
}
