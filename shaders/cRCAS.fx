#define CSHADE_RCAS

/*
    https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK
    https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/sdk/include/FidelityFX/gpu/fsr1/ffx_fsr1.h

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

/*
    FSR - [RCAS] ROBUST CONTRAST ADAPTIVE SHARPENING

    CAS uses a simplified mechanism to convert local contrast into a variable amount of sharpness.
    RCAS uses a more exact mechanism, solving for the maximum local sharpness possible before clipping.
    RCAS also has a built in process to limit sharpening of what it detects as possible noise.
    RCAS sharper does not support scaling, as it should be applied after EASU scaling.
    Pass EASU output straight into RCAS, no color conversions necessary.

    RCAS is based on the following logic.
    RCAS uses a 5 tap filter in a cross pattern (same as CAS),
          w                n
        w 1 w  for taps  w m e
          w                s

    Where 'w' is the negative lobe weight.
        output = (w*(n+e+w+s)+m)/(4*w+1)

    RCAS solves for 'w' by seeing where the signal might clip out of the {0 to 1} input range,
        0 == (w*(n+e+w+s)+m)/(4*w+1) -> w = -m/(n+e+w+s)
        1 == (w*(n+e+w+s)+m)/(4*w+1) -> w = (1-m)/(n+e+w+s-4*1)

    Then chooses the 'w' which results in no clipping, limits 'w', and multiplies by the 'sharp' amount.
    This solution above has issues with MSAA input as the steps along the gradient cause edge detection issues.
    So RCAS uses 4x the maximum and 4x the minimum (depending on equation)in place of the individual taps.
    As well as switching from 'm' to either the minimum or maximum (depending on side), to help in energy conservation.
    This stabilizes RCAS.

    RCAS does a simple highpass which is normalized against the local contrast then shaped,
             0.25
        0.25  -1  0.25
             0.25
    This is used as a noise detection filter, to reduce the effect of RCAS on grain, and focus on real edges.
*/

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Mask\0";
> = 0;

uniform float _Sharpening <
    ui_label = "Sharpening";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

#define FSR_RCAS_LIMIT (0.25 - (1.0 / 16.0))

void FFX_RCAS(
    inout float4 FilterShape,
    inout float4 FilterMask,
    in float2 Tex,
    in float2 Delta,
    in float Sharpening
)
{
    float4 TexArray[2];
    TexArray[0] = Tex.xyxy + (Delta.xyxy * float4(-1.0, 0.0, 1.0, 0.0));
    TexArray[1] = Tex.xyxy + (Delta.xyxy * float4(0.0, -1.0, 0.0, 1.0));

    float4 Sample[5];
    Sample[0] = CShade_BackBuffer2D(Tex);
    Sample[1] = CShade_BackBuffer2D(TexArray[0].xy);
    Sample[2] = CShade_BackBuffer2D(TexArray[0].zw);
    Sample[3] = CShade_BackBuffer2D(TexArray[1].xy);
    Sample[4] = CShade_BackBuffer2D(TexArray[1].zw);

    // Luma times 2.
    float Luma[5];
    const float3 LumaWeight = float3(0.5, 1.0, 0.5);
    Luma[0] = dot(Sample[0].rgb, LumaWeight);
    Luma[1] = dot(Sample[1].rgb, LumaWeight);
    Luma[2] = dot(Sample[2].rgb, LumaWeight);
    Luma[3] = dot(Sample[3].rgb, LumaWeight);
    Luma[4] = dot(Sample[4].rgb, LumaWeight);

    // Noise detection using a normalized local contrast filter
    float Noise = ((Luma[1] + Luma[2] + Luma[3] + Luma[4]) * 0.25) - Luma[0];
    float MaxLuma = max(Luma[0], max(max(Luma[1], Luma[2]), max(Luma[3], Luma[4])));
    float MinLuma = min(Luma[0], min(min(Luma[1], Luma[2]), min(Luma[3], Luma[4])));
    float RangeLuma = MaxLuma - MinLuma;
    Noise = saturate(abs(Noise) / RangeLuma);
    Noise = (-0.5 * Noise) + 1.0;

    // Min and max of ring.
    float4 MaxRGB = max(max(Sample[1], Sample[2]), max(Sample[3], Sample[4]));
    float4 MinRGB = min(min(Sample[1], Sample[2]), min(Sample[3], Sample[4]));

    // Immediate constants for peak range.
    float2 PeakC = float2(1.0, -1.0 * 4.0);

    // Limiters, these need to be high precision RCPs.
    float4 HitMinRGB = MinRGB / (4.0 * MaxRGB);
    float4 HitMaxRGB = (PeakC.x - MaxRGB) / ((4.0 * MinRGB) + PeakC.y);
    float4 LobeRGB = max(-HitMinRGB, HitMaxRGB);
    float MaxLobe = max(max(LobeRGB.r, LobeRGB.g), LobeRGB.b);

    Sharpening = 1.0 - Sharpening;
    float4 Lobe = max(-FSR_RCAS_LIMIT, min(MaxLobe, 0.0)) * exp2(-Sharpening);

    // Apply noise removal
    Lobe *= Noise;

    // Resolve
    float4 RcpL = 1.0 / ((4.0 * Lobe) + 1.0);
    FilterShape = Sample[0];
    FilterShape += (Lobe * Sample[1]);
    FilterShape += (Lobe * Sample[2]);
    FilterShape += (Lobe * Sample[3]);
    FilterShape += (Lobe * Sample[4]);
    FilterShape *= RcpL;

    FilterMask = -Lobe;
}

float4 PS_RCAS(CShade_VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float4 OutputMask = 1.0;
    FFX_RCAS(
        OutputColor,
        OutputMask,
        Input.Tex0,
        fwidth(Input.Tex0.xy),
        _Sharpening
    );

    if (_RenderMode == 1)
    {
        OutputColor = OutputMask;
    }

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_RCAS < ui_tooltip = "AMD FidelityFX | Robust Contrast Adaptive Sharpening (RCAS)"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_RCAS;
    }
}
