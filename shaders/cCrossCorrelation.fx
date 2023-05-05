#include "shared/cGraphics.fxh"

namespace CrossCorrelation
{
    CREATE_TEXTURE(CurrentTex, BUFFER_SIZE_0, R8, 1)
    CREATE_SAMPLER(SampleCurrentTex, CurrentTex, LINEAR, CLAMP)

    CREATE_TEXTURE(PreviousTex, BUFFER_SIZE_0, R8, 1)
    CREATE_SAMPLER(SamplePreviousTex, PreviousTex, LINEAR, CLAMP)

    // Vertex shaders

    struct VS2PS_SAD
    {
        float4 HPos : SV_POSITION;
        float4 Tex0 : TEXCOORD0;
        float4 Tex1 : TEXCOORD1;
        float4 Tex2 : TEXCOORD2;
    };

    VS2PS_SAD VS_SAD(APP2VS Input)
    {
        float2 PixelSize = 1.0 / (float2(BUFFER_WIDTH, BUFFER_HEIGHT));

        VS2PS_Quad FSQuad = VS_Quad(Input);

        VS2PS_SAD Output;
        Output.HPos = FSQuad.HPos;
        Output.Tex0 = FSQuad.Tex0.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        Output.Tex1 = FSQuad.Tex0.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        Output.Tex2 = FSQuad.Tex0.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        return Output;
    }

    // Pixel shaders

    float PS_Blit0(VS2PS_Quad Input) : SV_TARGET0
    {
        float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
        return dot(Color, 1.0 / 3.0);
    }

    float4 PS_SAD(VS2PS_SAD Input) : SV_TARGET0
    {
        const int Window = 9;
        const float MeanWeight = 1.0 / Window;

        float2 SamplePos[Window] =
        {
            Input.Tex0.xy, Input.Tex1.xy, Input.Tex2.xy,
            Input.Tex0.xz, Input.Tex1.xz, Input.Tex2.xz,
            Input.Tex0.xw, Input.Tex1.xw, Input.Tex2.xw
        };

        float2 Images[Window];
        float2 Images_mean = 0.0;

        for (int i = 0; i < Window; i++)
        {
            Images[i][0] = tex2D(SamplePreviousTex, SamplePos[i]).r;
            Images[i][1] = tex2D(SampleCurrentTex, SamplePos[i]).r;
            Images_mean += (Images[i] * MeanWeight);
        }

        // [0] = Numerator; [1] = Denominator A; [2] = Denominator B
        float3 NCC = 0.0;
        for (int j = 0; j < Window; j++)
        {
            float2 Images_D = Images[j] - Images_mean;
            NCC += (Images_D.xyx * Images_D.xyy);
        }
        float D = sqrt(NCC[0] * NCC[1]);
        float Output = (D != 0.0) ? NCC[2] / D : 1.0;
        return Output * 0.5 + 0.5;
    }

    float4 PS_Blit1(VS2PS_Quad Input) : SV_TARGET0
    {
        return tex2D(SampleCurrentTex, Input.Tex0);
    }

    technique CShade_CrossCorrelation
    {
        pass
        {
            VertexShader = VS_Quad;
            PixelShader = PS_Blit0;

            RenderTarget0 = CurrentTex;
        }

        pass
        {
            SRGBWriteEnable = WRITE_SRGB;

            VertexShader = VS_SAD;
            PixelShader = PS_SAD;
        }

        pass
        {
            VertexShader = VS_Quad;
            PixelShader = PS_Blit1;

            RenderTarget0 = PreviousTex;
        }
    }
}
