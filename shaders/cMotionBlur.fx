
namespace cMotionBlur
{
    /*
        [Shader Options]
    */

    uniform float _FrameTime < source = "frametime"; > ;

    uniform float _MipBias <
        ui_category = "Optical Flow";
        ui_label = "Mipmap Bias";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 7.0;
    > = 4.5;

    uniform float _BlendFactor <
        ui_category = "Optical Flow";
        ui_label = "Temporal Blending Factor";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 0.9;
    > = 0.25;

    uniform float _Scale <
        ui_category = "Motion Blur";
        ui_label = "Scale";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _TargetFrameRate <
        ui_category = "Motion Blur";
        ui_label = "Target Frame-Rate";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 144.0;
    > = 60.0;

    uniform bool _FrameRateScaling <
        ui_category = "Motion Blur";
        ui_label = "Frame-Rate Scaling";
        ui_type = "radio";
    > = false;

    #include "shared/cShade.fxh"
    #include "shared/cColor.fxh"
    #include "shared/cBlur.fxh"
    #include "shared/cMotionEstimation.fxh"
    #include "shared/cProcedural.fxh"
    #include "shared/cBlend.fxh"

    /*
        [Textures & Samplers]
    */

    CREATE_TEXTURE_POOLED(TempTex1_RG8, BUFFER_SIZE_1, RG8, 3)
    CREATE_TEXTURE_POOLED(TempTex2a_RG16F, BUFFER_SIZE_2, RG16F, 8)
    CREATE_TEXTURE_POOLED(TempTex2b_RG16F, BUFFER_SIZE_2, RG16F, 8)
    CREATE_TEXTURE_POOLED(TempTex3_RG16F, BUFFER_SIZE_3, RG16F, 1)
    CREATE_TEXTURE_POOLED(TempTex4_RG16F, BUFFER_SIZE_4, RG16F, 1)
    CREATE_TEXTURE_POOLED(TempTex5_RG16F, BUFFER_SIZE_5, RG16F, 1)

    CREATE_SAMPLER(SampleTempTex1, TempTex1_RG8, LINEAR, MIRROR)
    CREATE_SAMPLER(SampleTempTex2a, TempTex2a_RG16F, LINEAR, MIRROR)
    CREATE_SAMPLER(SampleTempTex2b, TempTex2b_RG16F, LINEAR, MIRROR)
    CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, MIRROR)
    CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, MIRROR)
    CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, MIRROR)

    CREATE_TEXTURE(Tex2c, BUFFER_SIZE_2, RG16F, 8)
    CREATE_SAMPLER(SampleTex2c, Tex2c, LINEAR, MIRROR)

    CREATE_TEXTURE(OFlowTex, BUFFER_SIZE_2, RG16F, 1)
    CREATE_SAMPLER(SampleOFlowTex, OFlowTex, LINEAR, MIRROR)

    /*
        [Pixel Shaders]
    */

    float2 PS_Normalize(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float3 Color = tex2D(CShade_SampleColorTex, Input.Tex0).rgb;
        return CColor_GetSphericalRG(Color).xy;
    }

    float2 PS_PrefilterHBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        return CBlur_GetPixelBlur(Input, SampleTempTex1, true).rg;
    }

    float2 PS_PrefilterVBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        return CBlur_GetPixelBlur(Input, SampleTempTex2a, false).rg;
    }

    // Run Lucas-Kanade

    float2 PS_LucasKanade4(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = 0.0;
        return CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex2b);
    }

    float2 PS_LucasKanade3(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTempTex5, Input.Tex0).xy;
        return CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex2b);
    }

    float2 PS_LucasKanade2(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTempTex4, Input.Tex0).xy;
        return CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex2b);
    }

    float4 PS_LucasKanade1(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = tex2D(SampleTempTex3, Input.Tex0).xy;
        return float4(CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex2b), 0.0, _BlendFactor);
    }

    // Postfilter blur

    // We use MRT to immeduately copy the current blurred frame for the next frame
    float4 PS_PostfilterHBlur(CShade_VS2PS_Quad Input, out float4 Copy : SV_TARGET0) : SV_TARGET1
    {
        Copy = tex2D(SampleTempTex2b, Input.Tex0.xy);
        return float4(CBlur_GetPixelBlur(Input, SampleOFlowTex, true).rg, 0.0, 1.0);
    }

    float4 PS_PostfilterVBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        return float4(CBlur_GetPixelBlur(Input, SampleTempTex2a, false).rg, 0.0, 1.0);
    }

    float4 PS_MotionBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float4 OutputColor = 0.0;
        const int Samples = 16;

        float FrameRate = 1e+3 / _FrameTime;
        float FrameTimeRatio = _TargetFrameRate / FrameRate;

        float2 ScreenSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
        float2 ScreenCoord = Input.Tex0.xy;

        float2 Velocity = CMotionEstimation_UnpackMotionVectors(tex2Dlod(SampleTempTex2b, float4(Input.Tex0.xy, 0.0, _MipBias)).xy);

        float2 ScaledVelocity = Velocity * _Scale;
        ScaledVelocity = (_FrameRateScaling) ? ScaledVelocity / FrameTimeRatio : ScaledVelocity;

        [unroll]
        for (int k = 0; k < Samples; ++k)
        {
            float Random = (CProcedural_GetInterleavedGradientNoise(Input.HPos.xy + k) * 2.0) - 1.0;
            float2 RandomTex = Input.Tex0.xy + (ScaledVelocity * Random);
            OutputColor += tex2D(CShade_SampleColorTex, RandomTex);
        }

        return CBlend_OutputChannels(float4(OutputColor.rgb / Samples, _CShadeAlphaFactor));
    }

    #define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
        pass \
        { \
            VertexShader = VERTEX_SHADER; \
            PixelShader = PIXEL_SHADER; \
            RenderTarget0 = RENDER_TARGET; \
        }

    technique CShade_MotionBlur
    {
        // Normalize current frame
        CREATE_PASS(CShade_VS_Quad, PS_Normalize, TempTex1_RG8)

        // Prefilter blur
        CREATE_PASS(CShade_VS_Quad, PS_PrefilterHBlur, TempTex2a_RG16F)
        CREATE_PASS(CShade_VS_Quad, PS_PrefilterVBlur, TempTex2b_RG16F)

        // Bilinear Lucas-Kanade Optical Flow
        CREATE_PASS(CShade_VS_Quad, PS_LucasKanade4, TempTex5_RG16F)
        CREATE_PASS(CShade_VS_Quad, PS_LucasKanade3, TempTex4_RG16F)
        CREATE_PASS(CShade_VS_Quad, PS_LucasKanade2, TempTex3_RG16F)
        pass GetFineOpticalFlow
        {
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;

            VertexShader = CShade_VS_Quad;
            PixelShader = PS_LucasKanade1;
            RenderTarget0 = OFlowTex;
        }

        // Postfilter blur
        pass MRT_CopyAndBlur
        {
            VertexShader = CShade_VS_Quad;
            PixelShader = PS_PostfilterHBlur;
            RenderTarget0 = Tex2c;
            RenderTarget1 = TempTex2a_RG16F;
        }

        pass
        {
            VertexShader = CShade_VS_Quad;
            PixelShader = PS_PostfilterVBlur;
            RenderTarget0 = TempTex2b_RG16F;
        }

        // Motion blur
        pass
        {
            SRGBWriteEnable = WRITE_SRGB;
            CBLEND_CREATE_STATES()

            VertexShader = CShade_VS_Quad;
            PixelShader = PS_MotionBlur;
        }
    }
}
