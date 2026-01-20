#define CSHADE_MIRROR

/*
    This shader creates mirroring and kaleidoscope-like effects. It transforms the image by converting texture coordinates to polar coordinates, applying angular repetition, and then converting back. Users can adjust the angular division and offset to control the repetition pattern, apply a rotational roll, and enable symmetrical mirroring, resulting in visually complex and artistic distortions of the input image.
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

#include "shared/cMath.fxh"

/* Shader Options */

uniform float _Divisor <
    ui_label = "Mirroring Angle Division";
    ui_type = "drag";
    ui_tooltip = "Controls the angular division, creating a kaleidoscope or mirroring effect by repeating sections of the image.";
> = 0.05;

uniform float _Offset <
    ui_label = "Mirroring Angle Offset";
    ui_type = "drag";
    ui_tooltip = "Offsets the starting point of the angular division, shifting the mirrored pattern.";
> = 0.05;

uniform float _Roll <
    ui_label = "Mirroring Pattern Roll";
    ui_type = "drag";
    ui_tooltip = "Applies a rotational roll to the mirrored pattern.";
> = 0.0;

uniform bool _Symmetry <
    ui_label = "Symmetrical Mirroring";
    ui_type = "radio";
    ui_tooltip = "When enabled, the mirrored pattern will be symmetrical; otherwise, it will be a repeating pattern.";
> = true;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

/* Pixel Shaders */

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    // Convert to polar coordinates
    float2 Polar = CMath_UNORMtoSNORM_FLT2(Input.Tex0);
    float Phi = atan2(Polar.y, Polar.x);
    float Radius = length(Polar);

    // Angular repeating.
    Phi += _Offset;
    Phi = Phi - _Divisor * floor(Phi / _Divisor);
    Phi = (_Symmetry) ? min(Phi, _Divisor - Phi) : Phi;
    Phi += _Roll - _Offset;

    // Convert back to the texture coordinate.
    float2 PhiSinCos;
    sincos(Phi, PhiSinCos.x, PhiSinCos.y);
    float2 MirrorTex = CMath_SNORMtoUNORM_FLT2(PhiSinCos.yx * Radius);

    // Reflection at the border of the screen.
    MirrorTex = max(min(MirrorTex, 2.0 - MirrorTex), -MirrorTex);
    float4 Base = tex2D(CShade_SampleColorTex, MirrorTex);

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Base.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Base.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

technique CShade_KinoMirror
<
    ui_label = "CShade | KinoMirror";
    ui_tooltip = "Keijiro Takahashi's mirroring and kaleidoscope effect.";
>
{
    pass Mirror
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }
}
