
uniform float _Angle <
    ui_label = "Rotate Angle";
    ui_type = "drag";
> = 0.0;

uniform float2 _Translate <
    ui_label = "Translate";
    ui_type = "drag";
> = 0.0;

uniform float2 _Scale <
    ui_label = "Scale";
    ui_type = "drag";
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

void Matrix_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    float RotationAngle = radians(_Angle);

    float2x2 RotationMatrix = float2x2
    (
    	cos(RotationAngle), -sin(RotationAngle), // Row 1
    	sin(RotationAngle), cos(RotationAngle) // Row 2
    );

    float3x3 TranslationMatrix = float3x3
    (
    	1.0, 0.0, 0.0, // Row 1
    	0.0, 1.0, 0.0, // Row 2
    	_Translate.x, _Translate.y, 1.0 // Row 3
    );
    
    float2x2 ScalingMatrix = float2x2
    (
    	_Scale.x, 0.0, // Row 1
    	0.0, _Scale.y // Row 2
    );

    // Scale TexCoord from [0,1] to [-1,1]
    TexCoord = TexCoord * 2.0 - 1.0;

    // Do transformations here
	TexCoord = mul(TexCoord, RotationMatrix);
	TexCoord = mul(float3(TexCoord, 1.0), TranslationMatrix).xy;
	TexCoord = mul(TexCoord, ScalingMatrix);

    // Scale TexCoord from [-1,1] to [0,1]
    TexCoord = TexCoord.xy * 0.5 + 0.5;
}

// Pixel shaders

void Matrix_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(Sample_Color, TexCoord);
}

technique cMatrixMath
{
    pass
    {
        VertexShader = Matrix_VS;
        PixelShader = Matrix_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
