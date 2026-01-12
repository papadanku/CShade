#define CSHADE_NOISEBLUR

/*
    This shader applies a noise-based blur effect, creating a diffused, noisy blur by sampling multiple points around each pixel in a randomized disk pattern. It offers controls for blur strength and an optional falloff effect that adjusts blur intensity towards the screen edges. The falloff can also be inverted to increase blur intensity at the edges.
*/

/*
    MIT License

    Copyright (C) 2015 Keijiro Takahashi

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "shared/cLens.fxh"
#include "shared/cMath.fxh"

/*
    [Shader Options]
*/

uniform bool _EnableFalloff <
    ui_category = "Main Shader";
    ui_label = "Enable Edge Falloff";
    ui_tooltip = "When enabled, the blur intensity will decrease towards the edges of the screen.";
    ui_type = "radio";
> = true;

uniform bool _InvertFalloff <
    ui_category = "Main Shader";
    ui_label = "Invert Edge Falloff";
    ui_type = "radio";
    ui_tooltip = "When enabled, the blur intensity will be higher at the edges and lower in the center.";
> = false;

uniform float _Radius <
    ui_category = "Main Shader";
    ui_label = "Blur Strength";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the overall radius or spread of the noise blur effect.";
> = 0.5;

uniform float _FalloffAmount <
    ui_category = "Main Shader";
    ui_label = "Falloff Intensity";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls how quickly the blur intensity changes from the center to the edges when falloff is enabled.";
> = 0.6;

uniform float2 _FalloffOffset <
    ui_category = "Main Shader";
    ui_label = "Falloff Center Offset";
    ui_max = 1.0;
    ui_min = -1.0;
    ui_step = 0.001;
    ui_type = "slider";
    ui_tooltip = "Adjusts the center point of the blur radius falloff effect.";
> = float2(0.0, 0.0);

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Pixel Shaders]
*/

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float Pi2 = CMath_GetPi() * 2.0;
    const float2 ScreenSize = int2(BUFFER_WIDTH, BUFFER_HEIGHT);
    const float2 PixelSize = 1.0 / ScreenSize;
    const int Taps = 4;
    const int Sum = Taps - 1;

    float Noise = Pi2 * CMath_GetHash_FLT1(Input.HPos.xy, 0.0);
    float2 UNormTex = CMath_UNORMtoSNORM_FLT2(Input.Tex0);

    float2 Rotation = 0.0;
    sincos(Noise, Rotation.y, Rotation.x);
    float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y, -Rotation.y, Rotation.x);

    float Height = saturate(1.0 - saturate(pow(abs(Input.Tex0.y), 1.0)));
    float AspectRatio = ScreenSize.y * (1.0 / ScreenSize.x);

    // Compute optional radius falloff
    float Falloff = 1.0;
    if (_EnableFalloff)
    {
        Falloff = CLens_GetVignetteMask(UNormTex + _FalloffOffset, 0.0, _FalloffAmount);
        Falloff = _InvertFalloff ? Falloff : 1.0 - Falloff;
    }

    Output = 0.0;
    float Weight = 0.0;

    [unroll]
    for (int i = 0; i < Taps ; i++)
    {
        [unroll]
        for (int j = 0; j < Taps ; j++)
        {
            float2 Shift = float2(i, j) / float(Sum);
            Shift = CMath_UNORMtoSNORM_FLT2(Shift);

            float2 DiskShift = CMath_MapUVtoConcentricDisk(Shift);
            DiskShift = mul(DiskShift * 3.0, RotationMatrix);
            DiskShift *= Falloff;
            DiskShift *= _Radius;
            DiskShift.x *= AspectRatio;

            float2 FetchTex = Input.Tex0 + (DiskShift * 0.01);
            Output += tex2D(CShade_SampleColorTex, FetchTex);
            Weight += 1.0;
        }
    }

    Output = CBlend_OutputChannels(Output.rgb / Weight, _CShade_AlphaFactor);
}

technique CShade_NoiseBlur
<
    ui_label = "CShade / Noise Blur";
    ui_tooltip = "Adjustable noise blur effect.";
>
{
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
