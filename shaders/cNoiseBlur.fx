
#include "shared/cShade.fxh"
#include "shared/cProcedural.fxh"
#include "shared/cMath.fxh"
#include "shared/fidelityfx/cLens.fxh"

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

/*
    [Shader Options]
*/

uniform float _Radius <
    ui_label = "Radius";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float _FalloffAmount <
    ui_label = "Falloff Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 2.0;
> = 0.6;

uniform float2 _FalloffOffset <
    ui_label = "Falloff Offset";
    ui_type = "slider";
    ui_step = 0.001;
    ui_min = -1.0;
    ui_max = 1.0;
> = float2(0.0, 0.0);

uniform bool _EnableFalloff <
    ui_label = "Enable Radius Falloff";
    ui_type = "radio";
> = true;

uniform bool _InvertFalloff <
    ui_label = "Invert Radius Falloff";
    ui_type = "radio";
> = false;


/*
    [Pixel Shaders]
*/

float4 PS_NoiseBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float4 OutputColor = 0.0;

    float Pi2 = CMath_GetPi() * 2.0;
    const float2 ScreenSize = int2(BUFFER_WIDTH, BUFFER_HEIGHT);
    const float2 PixelSize = 1.0 / ScreenSize;

    float Noise = Pi2 * CProcedural_GetGradientNoise1(Input.Tex0.xy * 256.0, 0.0, false);
    float2 UNormTex = (Input.Tex0 * 2.0) - 1.0;

    float2 Rotation = 0.0;
    sincos(Noise, Rotation.y, Rotation.x);

    float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y,
                                      -Rotation.y, Rotation.x);

    float Height = saturate(1.0 - saturate(pow(abs(Input.Tex0.y), 1.0)));
    float AspectRatio = ScreenSize.y * (1.0 / ScreenSize.x);

    // Compute optional radius falloff
    float3 FalloffFactor = 1.0;

    if (_EnableFalloff)
    {
        FFX_Lens_ApplyVignette(clamp(UNormTex + _FalloffOffset, -1.0, 1.0), 0.0, FalloffFactor, _FalloffAmount);
    }

    FalloffFactor = _InvertFalloff ? FalloffFactor : 1.0 - FalloffFactor;

    float4 Weight = 0.0;
    [unroll] for(int i = 1; i < 4; ++i)
    {
        [unroll] for(int j = 0; j < 4 * i; ++j)
        {
            float Shift = (Pi2 / (4.0 * float(i))) * float(j);
            float2 AngleShift = 0.0;
            sincos(Shift, AngleShift.x, AngleShift.y);
            AngleShift *= float(i);

            float2 SampleOffset = mul(AngleShift, RotationMatrix) * FalloffFactor.xy;
            SampleOffset *= _Radius;
            SampleOffset.x *= AspectRatio;
            OutputColor += tex2D(CShade_SampleColorTex, Input.Tex0 + (SampleOffset * 0.01));
            Weight++;
        }
    }

    return OutputColor / Weight;
}

technique CShade_NoiseBlur
{
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_NoiseBlur;
    }
}
