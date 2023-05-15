#include "shared/cGraphics.fxh"
#include "shared/cImageProcessing.fxh"
#include "shared/cVideoProcessing.fxh"

namespace cTemplateMatching
{
    /*
        [Shader parameters]
    */

    CREATE_OPTION(float, _MipBias, "Optical flow", "Optical flow mipmap bias", "slider", 7.0, 0.0)
    CREATE_OPTION(float, _BlendFactor, "Optical flow", "Temporal blending factor", "slider", 0.9, 0.0)

    CREATE_TEXTURE(Tex1, BUFFER_SIZE_1, R8, 3)
    CREATE_SAMPLER(SampleTex1, Tex1, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex2a, BUFFER_SIZE_2, R8, 8)
    CREATE_SAMPLER(SampleTex2a, Tex2a, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex2b, BUFFER_SIZE_2, R8, 8)
    CREATE_SAMPLER(SampleTex2b, Tex2b, LINEAR, MIRROR)

    CREATE_TEXTURE(OFlowTex, BUFFER_SIZE_2, RG16F, 1)
    CREATE_SAMPLER(SampleOFlowTex, OFlowTex, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex3, BUFFER_SIZE_3, RG16F, 1)
    CREATE_SAMPLER(SampleTex3, Tex3, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex4, BUFFER_SIZE_4, RG16F, 1)
    CREATE_SAMPLER(SampleTex4, Tex4, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex5, BUFFER_SIZE_5, RG16F, 1)
    CREATE_SAMPLER(SampleTex5, Tex5, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex6, BUFFER_SIZE_6, RG16F, 1)
    CREATE_SAMPLER(SampleTex6, Tex6, LINEAR, MIRROR)

    // Pixel shaders

    float PS_Saturation(VS2PS_Quad Input) : SV_TARGET0
    {
        float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
        return SaturateRGB(Color);
    }

    // Copy-back
    float4 PS_Copy_0(VS2PS_Quad Input) : SV_TARGET0
    {
        return tex2D(SampleTex1, Input.Tex0.xy);
    }

    // Run motion estimation

    float2 PS_MFlow_Level5(VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = 0.0;
        return GetPixelMFlow(Input.Tex0, Vectors, SampleTex2b, SampleTex2a, 4);
    }

    float2 PS_MFlow_Level4(VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTex6, Input.Tex0).xy;
        return GetPixelMFlow(Input.Tex0, Vectors, SampleTex2b, SampleTex2a, 3);
    }

    float2 PS_MFlow_Level3(VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTex5, Input.Tex0).xy;
        return GetPixelMFlow(Input.Tex0, Vectors, SampleTex2b, SampleTex2a, 2);
    }

    float2 PS_MFlow_Level2(VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTex4, Input.Tex0).xy;
        return GetPixelMFlow(Input.Tex0, Vectors, SampleTex2b, SampleTex2a, 1);
    }

    float4 PS_MFlow_Level1(VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTex3, Input.Tex0).xy;
        return float4(GetPixelMFlow(Input.Tex0, Vectors, SampleTex2b, SampleTex2a, 0), 0.0, _BlendFactor);
    }

    // Copy-back
    float4 PS_Copy_1(VS2PS_Quad Input) : SV_TARGET0
    {
        return tex2D(SampleTex2a, Input.Tex0.xy);
    }

    float4 PS_Display(VS2PS_Quad Input) : SV_TARGET0
    {
        float2 InvTexSize = float2(ddx(Input.Tex0.x), ddy(Input.Tex0.y));

        float2 Vectors = tex2Dlod(SampleOFlowTex, float4(Input.Tex0.xy, 0.0, _MipBias)).xy;
        Vectors = DecodeVectors(Vectors, InvTexSize);

        float3 NVectors = normalize(float3(Vectors, 1.0));
        NVectors = saturate((NVectors * 0.5) + 0.5);

        return float4(NVectors, 1.0);
    }

    #define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
        pass \
        { \
            VertexShader = VERTEX_SHADER; \
            PixelShader = PIXEL_SHADER; \
            RenderTarget0 = RENDER_TARGET; \
        }

    technique CShade_TemplateMatching
    {
        // Normalize current frame
        CREATE_PASS(VS_Quad, PS_Saturation, Tex1)

        // Prefilter blur
        CREATE_PASS(VS_Quad, PS_Copy_0, Tex2a)

        // Block matching
        CREATE_PASS(VS_Quad, PS_MFlow_Level5, Tex6)
        CREATE_PASS(VS_Quad, PS_MFlow_Level4, Tex5)
        CREATE_PASS(VS_Quad, PS_MFlow_Level3, Tex4)
        CREATE_PASS(VS_Quad, PS_MFlow_Level2, Tex3)
        pass GetFineTemplateMatching
        {
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;

            VertexShader = VS_Quad;
            PixelShader = PS_MFlow_Level1;
            RenderTarget0 = OFlowTex;
        }

        // Postfilter blur
        pass Copy
        {
            VertexShader = VS_Quad;
            PixelShader = PS_Copy_1;
            RenderTarget0 = Tex2b;
        }

        // Display
        pass
        {
            SRGBWriteEnable = WRITE_SRGB;

            VertexShader = VS_Quad;
            PixelShader = PS_Display;
        }
    }
}