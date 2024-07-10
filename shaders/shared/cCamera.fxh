
#if !defined(INCLUDE_CAMERA)
    #define INCLUDE_CAMERA

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html

    float GetLogLuminance(float3 Color)
    {
        float Luminance = max(max(Color.r, Color.g), Color.b);
        return log(max(Luminance, 1e-2));
    }

    #if defined(INCLUDE_CCAMERA_INPUT)
        uniform float _CShadeExposureSmoothingSpeed <
            ui_category = "Output: AutoExposure";
            ui_label = "Smoothing Speed";
            ui_type = "slider";
            ui_min = 0.1;
            ui_max = 1.0;
        > = 0.1;

        float4 CreateExposureTex(float Luminance, float FrameTime)
        {
            // .rgb = Output the highest brightness out of red/green/blue component
            // .a = Output the weight for temporal blending
            float Delay = 1e-3 * FrameTime;
            return float4((float3)Luminance, saturate(Delay * _CShadeExposureSmoothingSpeed));
        }
    #endif

    #if defined(INCLUDE_CCAMERA_OUTPUT)
        uniform float _CShadeExposureBias <
            ui_category = "Output: AutoExposure";
            ui_label = "Exposure Compensation";
            ui_type = "slider";
            ui_step = 0.001;
            ui_min = -4.0;
            ui_max = 4.0;
        > = 1.0;

        uniform float _CShadeExposureRange <
            ui_category = "Output: AutoExposure";
            ui_label = "Exposure Compensation Range";
            ui_type = "slider";
            ui_step = 0.001;
            ui_min = 0.0;
            ui_max = 4.0;
        > = 1.0;

        float3 ApplyAutoExposure(float3 Color, float Luma)
        {
            float LumaAverage = exp(Luma);
            float Ev100 = log2(LumaAverage * 100.0 / 12.5);
            Ev100 -= _CShadeExposureBias; // optional manual bias
            Ev100 = clamp(Ev100, -_CShadeExposureRange, _CShadeExposureRange);
            float Exposure = 1.0 / (1.2 * exp2(Ev100));
            return Color * Exposure;
        }
    #endif

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

    float GetVignette(float2 Tex, float AspectRatio, float Falloff, float2 FalloffOffset)
    {
        Tex = ((Tex * 2.0 - 1.0) + FalloffOffset) * AspectRatio;
        float Radius = length(Tex) * Falloff;
        float Radius_2_1 = (Radius * Radius) + 1.0;
        return 1.0 / (Radius_2_1 * Radius_2_1);
    }

#endif