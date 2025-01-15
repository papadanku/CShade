#define CSHADE_CAS

/*
    https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK
    https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/sdk/include/FidelityFX/gpu/cas/ffx_cas.h

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

#include "shared/cColor.fxh"

/*
    [Shader Options]
*/

uniform int _RenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Mask\0";
> = 0;

uniform int _Kernel <
    ui_category = "Sharpening";
    ui_label = "Kernel Shape";
    ui_type = "combo";
    ui_items = "Diamond\0Box\0";
> = 1;

uniform float _Contrast <
    ui_category = "Sharpening";
    ui_label = "Contrast";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

void FFX_CAS(
    inout float4 FilterShape,
    inout float4 FilterMask,
    in float2 Tex,
    in float2 Delta,
    in int Kernel,
    in float Contrast
)
{
    // Select kernel sample
    float4 TexArray[3];
    float4 Sample[9];
    switch (Kernel)
    {
        case 0:
            TexArray[0] = Tex.xyxy + (Delta.xyxy * float4(-1.0, 0.0, 1.0, 0.0));
            TexArray[1] = Tex.xyxy + (Delta.xyxy * float4(0.0, -1.0, 0.0, 1.0));
            Sample[0] = CShade_BackBuffer2D(Tex);
            Sample[1] = CShade_BackBuffer2D(TexArray[0].xy);
            Sample[2] = CShade_BackBuffer2D(TexArray[0].zw);
            Sample[3] = CShade_BackBuffer2D(TexArray[1].xy);
            Sample[4] = CShade_BackBuffer2D(TexArray[1].zw);
            break;
        case 1:
            TexArray[0] = Tex.xyxy + (Delta.xyxy * float4(-1.0, 0.0, 1.0, 0.0));
            TexArray[1] = Tex.xyxy + (Delta.xyxy * float4(0.0, -1.0, 0.0, 1.0));
            TexArray[2] = Tex.xyxy + (Delta.xyxy * float4(-1.0, -1.0, 1.0, 1.0));
            Sample[0] = CShade_BackBuffer2D(Tex);
            Sample[1] = CShade_BackBuffer2D(TexArray[0].xy);
            Sample[2] = CShade_BackBuffer2D(TexArray[0].zw);
            Sample[3] = CShade_BackBuffer2D(TexArray[1].xy);
            Sample[4] = CShade_BackBuffer2D(TexArray[1].zw);
            Sample[5] = CShade_BackBuffer2D(TexArray[2].xw);
            Sample[6] = CShade_BackBuffer2D(TexArray[2].zw);
            Sample[7] = CShade_BackBuffer2D(TexArray[2].xy);
            Sample[8] = CShade_BackBuffer2D(TexArray[2].zy);
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

float4 PS_CAS(CShade_VS2PS_Quad Input): SV_TARGET0
{
    float4 OutputColor = 1.0;
    float4 OutputMask = 1.0;
    FFX_CAS(
        OutputColor,
        OutputMask,
        Input.Tex0,
        fwidth(Input.Tex0.xy),
        _Kernel,
        _Contrast
    );

    if (_RenderMode == 1)
    {
        OutputColor = OutputMask;
    }

    return CBlend_OutputChannels(float4(OutputColor.rgb, _CShadeAlphaFactor));
}

technique CShade_CAS < ui_tooltip = "AMD FidelityFX | Contrast Adaptive Sharpening (CAS)"; >
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CAS;
    }
}
