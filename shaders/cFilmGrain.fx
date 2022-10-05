
uniform float _Speed <
    ui_label = "Speed";
    ui_type = "drag";
> = 2.0f;

uniform float _Variance <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.5f;

uniform float _Intensity <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.005f;

uniform float _Time < source = "timer"; >;

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders
// "Well ill believe it when i see it."
// Yoinked code by Luluco250 (RIP) [https://www.shadertoy.com/view/4t2fRz] [MIT]

float Gaussian_Weight(float x, float Sigma)
{
    const float Pi = 3.14159265359;
    Sigma = Sigma * Sigma;
    return rsqrt(Pi * Sigma) * exp(-((x * x) / (2.0 * Sigma)));
}

void Film_Grain_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Time = rcp(1e+3 / _Time) * _Speed;
    float Seed = dot(Position.xy, float2(12.9898, 78.233));
    float Noise = frac(sin(Seed) * 43758.5453 + Time);
    OutputColor0 = Gaussian_Weight(Noise, _Variance) * _Intensity;
}

technique cFilmGrain
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Film_Grain_PS;
        // (Shader[Src] * SrcBlend) + (Buffer[Dest] * DestBlend)
        // This shader: (Shader[Src] * (1.0 - Buffer[Dest])) + Buffer[Dest]
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVDESTCOLOR;
        DestBlend = ONE;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
