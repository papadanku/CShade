
#include "shared/cBuffers.fxh"
#include "shared/cGraphics.fxh"
#include "shared/cCamera.fxh"
#include "shared/cTonemap.fxh"

/*
    [Shader Options]
*/

uniform float _Frametime < source = "frametime"; >;

uniform float _Threshold <
    ui_category = "Input Settings";
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.8;

uniform float _Smooth <
    ui_category = "Input Settings";
    ui_label = "Smoothing";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float _Saturation <
    ui_category = "Input Settings";
    ui_label = "Saturation";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 10.0;
> = 1.0;

uniform float3 _ColorShift <
    ui_category = "Input Settings";
    ui_label = "Color Shift (RGB)";
    ui_type = "color";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

uniform float _Intensity <
    ui_category = "Input Settings";
    ui_label = "Intensity";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 10.0;
> = 1.0;


/*
    [Textures & Samplers]
*/

#if USE_AUTOEXPOSURE
    CREATE_TEXTURE(ExposureTex, int2(1, 1), R16F, 0)
    CREATE_SAMPLER(SampleExposureTex, ExposureTex, LINEAR, CLAMP)
#endif

CREATE_SAMPLER(SampleTempTex0, TempTex0_RGB10A2, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex1, TempTex1_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex2, TempTex2_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex6, TempTex6_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex7, TempTex7_RGBA16F, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTempTex8, TempTex8_RGBA16F, LINEAR, CLAMP)


/*
    [Pixel Shaders]
    ---
    Thresholding: https://github.com/keijiro/Kino [MIT]
    Tonemapping: https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/

struct Sample
{
    float3 Color;
    float Weight;
};

float Med3(float x, float y, float z)
{
    return max(min(x, y), min(max(x, y), z));
}

float4 PS_Prefilter(VS2PS_Quad Input) : SV_TARGET0
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);

    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);

    #if USE_AUTOEXPOSURE
        // Apply auto-exposure here
        float Luma = tex2D(SampleExposureTex, Input.Tex0).r;
        Color = ApplyAutoExposure(Color.rgb, Luma);
    #endif

    // Under-threshold
    float Brightness = Med3(Color.r, Color.g, Color.b);
    float Response_Curve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    Response_Curve = Curve.z * Response_Curve * Response_Curve;

    // Combine and apply the brightness response curve
    Color = Color * max(Response_Curve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Brightness = Med3(Color.r, Color.g, Color.b);
    return float4(lerp(Brightness, Color.rgb, _Saturation) * _ColorShift, 1.0);
}

float GetKarisWeight(float3 c)
{
    float Brightness = max(max(c.r, c.g), c.b);
    return 1.0 / (Brightness + 1.0);
}

Sample GetKarisSample(sampler2D SamplerSource, float2 Tex)
{
    Sample Output;
    Output.Color = tex2D(SamplerSource, Tex).rgb;
    Output.Weight = GetKarisWeight(Output.Color);
    return Output;
}

float3 GetKarisAverage(Sample Group[4])
{
    float3 OutputColor = 0.0;
    float WeightSum = 0.0;

    for (int i = 0; i < 4; i++)
    {
        OutputColor += Group[i].Color;
        WeightSum += Group[i].Weight;
    }

    return OutputColor / WeightSum;
}

// 13-tap downsampling with Karis luma filtering
float4 GetPixelDownscale(VS2PS_Quad Input, sampler2D SampleSource, bool PartialKaris)
{
    float4 OutputColor0 = 0.0;

    // A0 -- B0 -- C0
    // -- D0 -- D1 --
    // A1 -- B1 -- C1
    // -- D2 -- D3 --
    // A2 -- B2 -- C2
    float2 PixelSize = fwidth(Input.Tex0.xy);
    float4 Tex0 = Input.Tex0.xyxy + (float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy);
    float4 Tex1 = Input.Tex0.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
    float4 Tex2 = Input.Tex0.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
    float4 Tex3 = Input.Tex0.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);

    if (PartialKaris)
    {
        Sample D0 = GetKarisSample(SampleSource, Tex0.xw);
        Sample D1 = GetKarisSample(SampleSource, Tex0.zw);
        Sample D2 = GetKarisSample(SampleSource, Tex0.xy);
        Sample D3 = GetKarisSample(SampleSource, Tex0.zy);

        Sample A0 = GetKarisSample(SampleSource, Tex1.xy);
        Sample A1 = GetKarisSample(SampleSource, Tex1.xz);
        Sample A2 = GetKarisSample(SampleSource, Tex1.xw);

        Sample B0 = GetKarisSample(SampleSource, Tex2.xy);
        Sample B1 = GetKarisSample(SampleSource, Tex2.xz);
        Sample B2 = GetKarisSample(SampleSource, Tex2.xw);

        Sample C0 = GetKarisSample(SampleSource, Tex3.xy);
        Sample C1 = GetKarisSample(SampleSource, Tex3.xz);
        Sample C2 = GetKarisSample(SampleSource, Tex3.xw);

        Sample GroupA[4] = { D0, D1, D2, D3 };
        Sample GroupB[4] = { A0, B0, A1, B1 };
        Sample GroupC[4] = { B0, C0, B1, C1 };
        Sample GroupD[4] = { A1, B1, A2, B2 };
        Sample GroupE[4] = { B1, C1, B2, C2 };

        OutputColor0 += (GetKarisAverage(GroupA) * 0.500);
        OutputColor0 += (GetKarisAverage(GroupB) * 0.125);
        OutputColor0 += (GetKarisAverage(GroupC) * 0.125);
        OutputColor0 += (GetKarisAverage(GroupD) * 0.125);
        OutputColor0 += (GetKarisAverage(GroupE) * 0.125);
    }
    else
    {
        float4 D0 = tex2D(SampleSource, Tex0.xw);
        float4 D1 = tex2D(SampleSource, Tex0.zw);
        float4 D2 = tex2D(SampleSource, Tex0.xy);
        float4 D3 = tex2D(SampleSource, Tex0.zy);

        float4 A0 = tex2D(SampleSource, Tex1.xy);
        float4 A1 = tex2D(SampleSource, Tex1.xz);
        float4 A2 = tex2D(SampleSource, Tex1.xw);

        float4 B0 = tex2D(SampleSource, Tex2.xy);
        float4 B1 = tex2D(SampleSource, Tex2.xz);
        float4 B2 = tex2D(SampleSource, Tex2.xw);

        float4 C0 = tex2D(SampleSource, Tex3.xy);
        float4 C1 = tex2D(SampleSource, Tex3.xz);
        float4 C2 = tex2D(SampleSource, Tex3.xw);

        float4 GroupA = D0 + D1 + D2 + D3;
        float4 GroupB = A0 + B0 + A1 + B1;
        float4 GroupC = B0 + C0 + B1 + C1;
        float4 GroupD = A1 + B1 + A2 + B2;
        float4 GroupE = B1 + C1 + B2 + C2;

        OutputColor0 += (GroupA * (0.500 / 4.0));
        OutputColor0 += (GroupB * (0.125 / 4.0));
        OutputColor0 += (GroupC * (0.125 / 4.0));
        OutputColor0 += (GroupD * (0.125 / 4.0));
        OutputColor0 += (GroupE * (0.125 / 4.0));
    }

    return OutputColor0;
}

#define CREATE_PS_DOWNSCALE(METHOD_NAME, SAMPLER, FLICKER_FILTER) \
    float4 METHOD_NAME(VS2PS_Quad Input) : SV_TARGET0 \
    { \
        return GetPixelDownscale(Input, SAMPLER, FLICKER_FILTER); \
    }

CREATE_PS_DOWNSCALE(PS_Downscale1, SampleTempTex0, true)
CREATE_PS_DOWNSCALE(PS_Downscale2, SampleTempTex1, false)
CREATE_PS_DOWNSCALE(PS_Downscale3, SampleTempTex2, false)
CREATE_PS_DOWNSCALE(PS_Downscale4, SampleTempTex3, false)
CREATE_PS_DOWNSCALE(PS_Downscale5, SampleTempTex4, false)
CREATE_PS_DOWNSCALE(PS_Downscale6, SampleTempTex5, false)
CREATE_PS_DOWNSCALE(PS_Downscale7, SampleTempTex6, false)
CREATE_PS_DOWNSCALE(PS_Downscale8, SampleTempTex7, false)

float4 PS_GetExposure(VS2PS_Quad Input) : SV_TARGET0
{
    float4 Color = tex2D(SampleTempTex8, Input.Tex0);
    return CreateExposureTex(Color.rgb, _Frametime);
}

float4 GetPixelUpscale(VS2PS_Quad Input, sampler2D SampleSource)
{
    // A0 B0 C0
    // A1 B1 C1
    // A2 B2 C2
    float2 PixelSize = fwidth(Input.Tex0);
    float4 Tex0 = Input.Tex0.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
    float4 Tex1 = Input.Tex0.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
    float4 Tex2 = Input.Tex0.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);

    float4 A0 = tex2D(SampleSource, Tex0.xy);
    float4 A1 = tex2D(SampleSource, Tex0.xz);
    float4 A2 = tex2D(SampleSource, Tex0.xw);

    float4 B0 = tex2D(SampleSource, Tex1.xy);
    float4 B1 = tex2D(SampleSource, Tex1.xz);
    float4 B2 = tex2D(SampleSource, Tex1.xw);

    float4 C0 = tex2D(SampleSource, Tex2.xy);
    float4 C1 = tex2D(SampleSource, Tex2.xz);
    float4 C2 = tex2D(SampleSource, Tex2.xw);

    float3 Weights = float3(1.0, 2.0, 4.0) / 16.0;
    float4 OutputColor = 0.0;
    OutputColor += ((A0 + C0 + A2 + C2) * Weights[0]);
    OutputColor += ((A1 + B0 + C1 + B2) * Weights[1]);
    OutputColor += (B1 * Weights[2]);
    return OutputColor;
}

#define CREATE_PS_UPSCALE(METHOD_NAME, SAMPLER) \
    float4 METHOD_NAME(VS2PS_Quad Input) : SV_TARGET0 \
    { \
        return GetPixelUpscale(Input, SAMPLER); \
    }

CREATE_PS_UPSCALE(PS_Upscale7, SampleTempTex8)
CREATE_PS_UPSCALE(PS_Upscale6, SampleTempTex7)
CREATE_PS_UPSCALE(PS_Upscale5, SampleTempTex6)
CREATE_PS_UPSCALE(PS_Upscale4, SampleTempTex5)
CREATE_PS_UPSCALE(PS_Upscale3, SampleTempTex4)
CREATE_PS_UPSCALE(PS_Upscale2, SampleTempTex3)
CREATE_PS_UPSCALE(PS_Upscale1, SampleTempTex2)

float4 PS_Composite(VS2PS_Quad Input) : SV_TARGET0
{
    float3 BaseColor = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
    float3 BloomColor = tex2D(SampleTempTex1, Input.Tex0).rgb;

    float4 Color = 1.0;
    Color.rgb = ApplyTonemap(BaseColor + (BloomColor * _Intensity));
    return Color;
}

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET, IS_ADDITIVE) \
    pass \
    { \
        ClearRenderTargets = FALSE; \
        BlendEnable = IS_ADDITIVE; \
        BlendOp = ADD; \
        SrcBlend = ONE; \
        DestBlend = ONE; \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_Bloom
{
    CREATE_PASS(VS_Quad, PS_Prefilter, TempTex0_RGB10A2, FALSE)

    CREATE_PASS(VS_Quad, PS_Downscale1, TempTex1_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale2, TempTex2_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale3, TempTex3_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale4, TempTex4_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale5, TempTex5_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale6, TempTex6_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale7, TempTex7_RGBA16F, FALSE)
    CREATE_PASS(VS_Quad, PS_Downscale8, TempTex8_RGBA16F, FALSE)

    #if USE_AUTOEXPOSURE
        pass CreateExposureTex
        {
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = SRCALPHA;
            DestBlend = INVSRCALPHA;

            VertexShader = VS_Quad;
            PixelShader = PS_GetExposure;

            RenderTarget0 = ExposureTex;
        }
    #endif

    CREATE_PASS(VS_Quad, PS_Upscale7, TempTex7_RGBA16F, TRUE)
    CREATE_PASS(VS_Quad, PS_Upscale6, TempTex6_RGBA16F, TRUE)
    CREATE_PASS(VS_Quad, PS_Upscale5, TempTex5_RGBA16F, TRUE)
    CREATE_PASS(VS_Quad, PS_Upscale4, TempTex4_RGBA16F, TRUE)
    CREATE_PASS(VS_Quad, PS_Upscale3, TempTex3_RGBA16F, TRUE)
    CREATE_PASS(VS_Quad, PS_Upscale2, TempTex2_RGBA16F, TRUE)
    CREATE_PASS(VS_Quad, PS_Upscale1, TempTex1_RGBA16F, TRUE)

    pass
    {
        ClearRenderTargets = FALSE;
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = VS_Quad;
        PixelShader = PS_Composite;
    }
}
