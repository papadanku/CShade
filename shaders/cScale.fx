
uniform float2 _Scale <
    ui_label = "Scale";
    ui_type = "drag";
    ui_step = 0.001;
> = 1.0;

uniform float2 _Offset <
    ui_label = "Center";
    ui_type = "drag";
    ui_step = 0.001;
> = float2(0.0, 0.0);

#ifndef ENABLE_POINT_SAMPLING
    #define ENABLE_POINT_SAMPLING 0
#endif

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    AddressU = MIRROR;
    AddressV = MIRROR;
    #if ENABLE_POINT_SAMPLING
        MagFilter = POINT;
        MinFilter = POINT;
        MipFilter = POINT;
    #else
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    #endif
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

void Scale_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // Scale texture coordinates from [0, 1] to [-1, 1] range
    TexCoord = TexCoord * 2.0 - 1.0;
    // Scale and offset in [-1, 1] range
    TexCoord = TexCoord * _Scale + _Offset;
    // Scale texture coordinates from [-1, 1] to [0, 1] range
    TexCoord = TexCoord * 0.5 + 0.5;
}

void Scale_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(Sample_Color, TexCoord);
}

technique cScale
{
    pass
    {
        VertexShader = Scale_VS;
        PixelShader = Scale_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
