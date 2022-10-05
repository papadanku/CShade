
namespace SumAbsoluteDifferences
{
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

    texture2D Render_Current
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = R8;
    };

    sampler2D Sample_Current
    {
        Texture = Render_Current;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Previous
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = R8;
    };

    sampler2D Sample_Previous
    {
        Texture = Render_Previous;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex shaders

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    void SAD_Offsets(in float2 TexCoord, in float2 PixelSize, out float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    }

    void SAD_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 LocalTexCoord = 0.0;
        Basic_VS(ID, Position, LocalTexCoord);
        SAD_Offsets(LocalTexCoord, 1.0 / (float2(BUFFER_WIDTH, BUFFER_HEIGHT)), Offsets);
    }

    // Pixel shaders

    void Blit_0_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        float3 Color = tex2D(Sample_Color, TexCoord).rgb;
        OutputColor0 = max(max(Color.r, Color.g), Color.b);
    }

    void Output_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
    	OutputColor0 = 0.0;
 
        float2 SamplePos[9] =
        {
            TexCoords[0].xy, TexCoords[1].xy, TexCoords[2].xy,
            TexCoords[0].xz, TexCoords[1].xz, TexCoords[2].xz,
            TexCoords[0].xw, TexCoords[1].xw, TexCoords[2].xw
        };

        for(int i = 0; i < 9; i++)
        {
            float I0 = tex2D(Sample_Previous, SamplePos[i]).r;
            float I1 = tex2D(Sample_Current, SamplePos[i]).r;
            OutputColor0 += abs(I1 - I0);
        }

        OutputColor0 = saturate(OutputColor0 / 9.0);
    }

    void Blit_1_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Sample_Current, TexCoord);
    }

    technique cSumAbsoluteDifferences
    {
        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Blit_0_PS;
            RenderTarget0 = Render_Current;
        }

        pass
        {
            VertexShader = SAD_VS;
            PixelShader = Output_PS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Blit_1_PS;
            RenderTarget0 = Render_Previous;
        }
    }
}
