#define CSHADE_CAS

/*
    This shader implements AMD FidelityFX Contrast Adaptive Sharpening (CAS). It sharpens the image by analyzing and adapting to local contrast, enhancing details without over-sharpening. The shader provides options for different sharpening kernel shapes (Diamond, Box) and allows users to adjust the sharpening contrast. Additionally, it can display a mask to visualize the areas where sharpening is applied.
*/

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

/* Shader Options */

uniform int _DisplayMode <
    ui_items = "Image\0Mask\0";
    ui_label = "Display Mode";
    ui_type = "combo";
    ui_tooltip = "Selects how the output is rendered: either the sharpened image or a mask showing where sharpening is applied.";
> = 0;

uniform int _Kernel <
    ui_items = "Diamond\0Box\0";
    ui_label = "Sharpening Kernel Shape";
    ui_type = "combo";
    ui_tooltip = "Determines the shape of the sampling kernel used for contrast detection, affecting how edges are identified.";
> = 0;

uniform float _Contrast <
    ui_label = "Sharpening Contrast";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the intensity of the sharpening effect based on local contrast. Higher values lead to more pronounced sharpening.";
> = 0.0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

struct CAS
{
    float4 Sample[5];
    float4 MinRGB;
    float4 MaxRGB;
};

CAS GetDiamondCAS(float2 Tex, float2 Delta)
{
    CAS O;

    float4 Tex0 = Tex.xyxy + (Delta.xyxy * float4(-1.0, 0.0, 1.0, 0.0));
    float4 Tex1 = Tex.xyxy + (Delta.xyxy * float4(0.0, -1.0, 0.0, 1.0));
    O.Sample[0] = tex2D(CShade_SampleColorTex, Tex);
    O.Sample[1] = tex2D(CShade_SampleColorTex, Tex0.xy);
    O.Sample[2] = tex2D(CShade_SampleColorTex, Tex0.zw);
    O.Sample[3] = tex2D(CShade_SampleColorTex, Tex1.xy);
    O.Sample[4] = tex2D(CShade_SampleColorTex, Tex1.zw);

    // Get polar min/max
    O.MinRGB = min(O.Sample[0], min(min(O.Sample[1], O.Sample[2]), min(O.Sample[3], O.Sample[4])));
    O.MaxRGB = max(O.Sample[0], max(max(O.Sample[1], O.Sample[2]), max(O.Sample[3], O.Sample[4])));

    return O;
}

CAS GetBoxCAS(float2 Tex, float2 Delta)
{
    CAS O;

    float4 Tex1 = Tex.xyyy + (Delta.xyyy * float4(-1.0, -1.0, 0.0, 1.0));
    float4 Tex2 = Tex.xyyy + (Delta.xyyy * float4(0.0, -1.0, 0.0, 1.0));
    float4 Tex3 = Tex.xyyy + (Delta.xyyy * float4(1.0, -1.0, 0.0, 1.0));

    /*
        1 2 3
        4 5 6
        7 8 9
    */
    float4 Sample1 = tex2D(CShade_SampleColorTex, Tex1.xy);
    float4 Sample2 = tex2D(CShade_SampleColorTex, Tex1.xz);
    float4 Sample3 = tex2D(CShade_SampleColorTex, Tex1.xw);
    float4 Sample4 = tex2D(CShade_SampleColorTex, Tex2.xy);
    float4 Sample5 = tex2D(CShade_SampleColorTex, Tex2.xz);
    float4 Sample6 = tex2D(CShade_SampleColorTex, Tex2.xw);
    float4 Sample7 = tex2D(CShade_SampleColorTex, Tex3.xy);
    float4 Sample8 = tex2D(CShade_SampleColorTex, Tex3.xz);
    float4 Sample9 = tex2D(CShade_SampleColorTex, Tex3.xw);

    // Get polar min/max
    float4 Min1 = min(Sample5, min(min(Sample2, Sample4), min(Sample6, Sample8)));
    float4 Min2 = min(Min1, min(min(Sample1, Sample3), min(Sample7, Sample9)));
    float4 Max1 = max(Sample5, max(max(Sample2, Sample4), max(Sample6, Sample8)));
    float4 Max2 = max(Max1, max(max(Sample1, Sample3), max(Sample7, Sample9)));

    O.Sample[0] = Sample5;
    O.Sample[1] = Sample2;
    O.Sample[2] = Sample4;
    O.Sample[3] = Sample6;
    O.Sample[4] = Sample8;

    O.MinRGB = Min1 + Min2;
    O.MaxRGB = Max1 + Max2;

    return O;
}

void FFX_CAS(
    inout float4 FilterShape,
    inout float4 FilterMask,
    in float2 Tex,
    in float2 Delta,
    in int Kernel,
    in float Contrast
)
{
    // Get CAS data based on user input
    CAS C;

    switch(Kernel)
    {
        case 0:
            C = GetDiamondCAS(Tex, Delta);
            break;
        case 1:
            C = GetBoxCAS(Tex, Delta);
            break;
    }

    // Smooth minimum distance to signal limit divided by smooth max.
    float4 ReciprocalMaxRGB = 1.0 / C.MaxRGB;
    float4 AmplifyRGB = saturate(min(C.MinRGB, 2.0 - C.MaxRGB) * ReciprocalMaxRGB);

    // Shaping amount of sharpening.
    AmplifyRGB = sqrt(AmplifyRGB);

    /* Filter shape.
            w   |   w   | w w
          w 1 w | w 1 w |  1
            w   |   w   | w w
    */
    float4 Peak = -(1.0 / lerp(8.0, 5.0, Contrast));
    float4 Weight = AmplifyRGB * Peak;
    float4 ReciprocalWeight = 1.0 / (1.0 + (4.0 * Weight));

    FilterShape = C.Sample[0];
    FilterShape += C.Sample[1] * Weight;
    FilterShape += C.Sample[2] * Weight;
    FilterShape += C.Sample[3] * Weight;
    FilterShape += C.Sample[4] * Weight;
    FilterShape = saturate(FilterShape * ReciprocalWeight);

    FilterMask = AmplifyRGB;
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 OutputMask = 1.0;
    FFX_CAS(
        Output,
        OutputMask,
        Input.Tex0,
        fwidth(Input.Tex0.xy),
        _Kernel,
        _Contrast
    );

    if (_DisplayMode == 1)
    {
        Output = OutputMask;
    }

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Output.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Output.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_CAS
<
    ui_label = "CShade | Contrast Adaptive Sharpening";
    ui_tooltip = "AMD FidelityFX Contrast Adaptive Sharpening (CAS).";
>
{
    pass ContrastAdaptiveSharpening
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
