
uniform float _Threshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float _Smooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
> = 0.5;

uniform float _Saturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 1.0;

uniform float _Intensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Intensity";
> = 1.0;

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float Median_3(float x, float y, float z)
{
    return max(min(x, y), min(max(x, y), z));
}

// Pixel shaders

void Threshold_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(Sample_Color, TexCoord);

    // Under-threshold
    float Brightness = Median_3(Color.r, Color.g, Color.b);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Brightness = Median_3(Color.r, Color.g, Color.b);
    OutputColor0 = saturate(lerp(Brightness, Color, _Saturation) * _Intensity);
}

technique cThreshold
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Threshold_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}