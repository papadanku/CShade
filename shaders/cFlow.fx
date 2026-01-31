#define CSHADE_FLOW

/*
    This shader calculates and visualizes optical flow using the Lucas-Kanade method. It analyzes motion between consecutive frames to generate motion vectors. The shader then visualizes these vectors using various display modes, including normalized or renormalized shading, and different Line Integral Convolution (LIC) visualizations. It also applies temporal smoothing to reduce flickering and offers control over the mipmap level for optical flow sampling.
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/* Preprocessor Definitions */

#ifndef SHADER_OPTICAL_FLOW_SAMPLING
    #define SHADER_OPTICAL_FLOW_SAMPLING POINT
#endif

#ifndef SHADER_VECTOR_STREAMING
    #define SHADER_VECTOR_STREAMING 1
#endif

#if SHADER_VECTOR_STREAMING
    #ifndef SHADER_VECTOR_STREAMING_CLEAR
        #define SHADER_VECTOR_STREAMING_CLEAR 0
    #endif

    #ifndef SHADER_VECTOR_STREAMING_ROWS
        #define SHADER_VECTOR_STREAMING_ROWS 64
    #endif

    #ifndef SHADER_VECTOR_STREAMING_COLUMNS
        #define SHADER_VECTOR_STREAMING_COLUMNS 64
    #endif

    #define VTX_COLUMNS SHADER_VECTOR_STREAMING_COLUMNS
    #define VTX_ROWS SHADER_VECTOR_STREAMING_ROWS
    #define VTX_PER_TRIANGLE 3
#endif

/* Shader Options */

#if !SHADER_VECTOR_STREAMING
    uniform int _DisplayMode <
        ui_label = "Display Mode";
        ui_type = "combo";
        ui_items = "Shading / Normalized\0Shading / Renormalized\0Line Integral Convolution\0Line Integral Convolution / Colored\0";
        ui_tooltip = "Selects the visual output mode for optical flow.";
    > = 0;
#endif

#if SHADER_VECTOR_STREAMING
    uniform float _StreamScaling <
        ui_label = "Vector Scaling";
        ui_max = 100.0;
        ui_min = 0.1;
        ui_type = "slider";
        ui_tooltip = "Amount of scaling applied to the displayed vectors.";
    > = 10.0;
#endif

uniform float _MipBias <
    ui_label = "Optical Flow Mipmap Level";
    ui_max = 7.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for sampling the optical flow map, affecting the detail and smoothness of the flow vectors.";
> = 0.0;

uniform float _BlendFactor <
    ui_label = "Flow Temporal Smoothing";
    ui_max = 0.9;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the temporal smoothing of the optical flow vectors, reducing flickering and making motion appear more fluid over time.";
> = 0.45;

#if SHADER_VECTOR_STREAMING
    #define CBLEND_APPLY_PRESET 1
    #define CSHADE_APPLY_AUTO_EXPOSURE 0
    #define CSHADE_APPLY_ABBERATION 0
    #define CSHADE_APPLY_GRAIN 0
    #define CSHADE_APPLY_VIGNETTE 0
    #define CSHADE_APPLY_GRADING 0
    #define CSHADE_APPLY_TONEMAP 0
    #define CSHADE_APPLY_DITHER 0
    #define CSHADE_DEBUG_PEAKING 0
    #include "shared/cShade.fxh"
#else
    #define CSHADE_APPLY_AUTO_EXPOSURE 0
    #define CSHADE_APPLY_ABBERATION 0
    #include "shared/cShade.fxh"
#endif

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nSHADER_OPTICAL_FLOW_SAMPLING - How the samples the optical flow map.\n\n\tOptions: LINEAR, POINT\n\nSHADER_VECTOR_STREAMING - Enables vector streaming visualization instead of shading.\n\n\tOptions: 0 (Disabled), 1 (Enabled)\n\nSHADER_VECTOR_STREAMING_ROWS - The number of rows used for vector streaming.\n\n\tOptions: Any integer value.\n\nSHADER_VECTOR_STREAMING_COLUMNS - The number of columns used for vector streaming.\n\n\tOptions: Any integer value.\n\nSHADER_VECTOR_STREAMING_CLEAR - Clears the render target before drawing vector streams. (0 = Disabled, 1 = Enabled)\n\n\tOptions: 0 (Disabled), 1 (Enabled)\n\n";
    ui_type = "radio";
> = 0;

/* Textures & Samplers */

CSHADE_CREATE_TEXTURE_POOLED(TempTex1_RGB10A2, CSHADE_BUFFER_SIZE_1, RGB10A2, 8)
CSHADE_CREATE_TEXTURE_POOLED(TempTex2_RG16F, CSHADE_BUFFER_SIZE_3, RG16F, 8)
CSHADE_CREATE_TEXTURE_POOLED(TempTex3_RG16F, CSHADE_BUFFER_SIZE_4, RG16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(TempTex4_RG16F, CSHADE_BUFFER_SIZE_5, RG16F, 1)
CSHADE_CREATE_TEXTURE_POOLED(TempTex5_RG16F, CSHADE_BUFFER_SIZE_6, RG16F, 1)

CSHADE_CREATE_SAMPLER(SampleTempTex1, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex2, TempTex2_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CSHADE_CREATE_TEXTURE(PreviousFrameTex, CSHADE_BUFFER_SIZE_1, RGB10A2, 8)
CSHADE_CREATE_SAMPLER_LODBIAS(SamplePreviousFrameTex, PreviousFrameTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CSHADE_CREATE_SAMPLER_LODBIAS(SampleCurrentFrameTex, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

CSHADE_CREATE_TEXTURE(FlowTex, CSHADE_BUFFER_SIZE_3, RG16F, 8)
CSHADE_CREATE_SAMPLER_LODBIAS(SampleGuide, FlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CSHADE_CREATE_SAMPLER(SampleFlow, TempTex2_RG16F, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)

#if !SHADER_VECTOR_STREAMING
    CSHADE_CREATE_TEXTURE(NoiseTex, CSHADE_BUFFER_SIZE_0, R16, 0)
    CSHADE_CREATE_SAMPLER(SampleNoiseTex, NoiseTex, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
#endif

/* Pixel Shaders: Pyramid */


void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
    float3 LogColor = CColor_EncodeLogC(Color.rgb) / CColor_EncodeLogC(1.0);

    float Sum = dot(LogColor, 1.0);
    float3 Ratio = abs(Sum) > 0.0 ? LogColor / Sum : 1.0 / 3.0;
    float MaxRatio = max(Ratio.r, max(Ratio.g, Ratio.b));
    float MaxColor = max(LogColor.r, max(LogColor.g, LogColor.b));

    Output.xy = MaxRatio > 0.0 ? Ratio.xy / MaxRatio : 1.0;
    Output.z = MaxColor;
    Output.w = 1.0;
}

/* Pixel Shaders: Lucas-Kanade */

void PS_LucasKanade4(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    float2 Vectors = 0.0;
    Output = CMotionEstimation_GetLucasKanade(true, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

void PS_LucasKanade3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex5).xy;
    Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

void PS_LucasKanade2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex4).xy;
    Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

void PS_LucasKanade1(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex3).xy;
    float2 Flow = CMotionEstimation_GetLucasKanade(false, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
    Output = float4(Flow, 0.0, _BlendFactor);
}

/* Pixel Shaders: Filtering */

void PS_Copy(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(SampleTempTex1, Input.Tex0.xy);
}

void PS_Median(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetMedian(SampleGuide, Input.Tex0).xy;
}

void PS_Upsample1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSelfBilateralUpsampleXY(SampleTempTex5, SampleGuide, Input.Tex0).xy;
}

void PS_Upsample2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSelfBilateralUpsampleXY(SampleTempTex4, SampleGuide, Input.Tex0).xy;
}

void PS_Upsample3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSelfBilateralUpsampleXY(SampleTempTex3, SampleGuide, Input.Tex0).xy;
}

/* Pixel Shaders: Output */

#if SHADER_VECTOR_STREAMING
    struct VS2PS_Cell
    {
        float4 HPos : SV_POSITION;
        float2 Tex0 : TEXCOORD0;
        float2 Velocity : TEXCOORD1;
    };

    void VS_VectorStreaming(in CShade_APP2VS Input, out VS2PS_Cell Output)
    {
        float Pi2 = CMath_GetPi() * 2.0;

        // Identify which triangle and which corner of the triangle we are on.
        int TriangleID = Input.ID / VTX_PER_TRIANGLE;
        int TriangleVertexID = CMath_GetModulus_FLT1(Input.ID, VTX_PER_TRIANGLE);

        // Column and Row information.
        int Column = CMath_GetModulus_FLT1(TriangleID, VTX_COLUMNS);
        int Row = TriangleID / VTX_COLUMNS;
        int IsOddRow = CMath_GetModulus_FLT1(Row, 2);

        // Calculate our Grid size and Triangle size.
        float2 GridSize = float2(VTX_COLUMNS, VTX_ROWS);
        float2 TriangleSize = 1.0 / max(GridSize, 1.0);

        // Calculate the Cell Origin.
        float2 VtxBasePos = float2(Column, Row);

        // We append some offsets to make the grid look more dynamic.
        float ShiftOdds = lerp(-0.25, 0.25, IsOddRow);
        VtxBasePos.x -= ShiftOdds;

        // Apply velocity to CellOffset.
        float4 VelocityTex = float4((VtxBasePos + 0.5) / GridSize, 0.0, _MipBias);
        float2 Velocity = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleFlow, VelocityTex).xy);

        /*
            Create our vertex offsets to make a triangle:

            ID2 (0, 2)
            · ·
            · · ·
            · · · ·
            · · · · ·
            · · · · · ·
            · · · · · · ·
            · · · · · · · ·
            ID0 (0, 0) · · ID1 (2, 0)

            NOTE: Scaled the texture coordinates by 2, so we can emulate quads with just 3 verticies in the pixel shader.
        */
        float2 Vertex;
        Vertex.x = (TriangleVertexID == 1) ? 2.0 : 0.0;
        Vertex.y = (TriangleVertexID == 2) ? 2.0 : 0.0;

        // Initiate vertex processing.
        float2 VtxOffset = Vertex;

        // Calculate the vertex directional information.
        float2 VtxDirection = Velocity * GridSize;
        float2 VtxScaleRotation = CMath_CartesianToPolar(-VtxDirection);

        // Scale across the adjacent side
        VtxOffset = (TriangleVertexID == 1) ? float2(VtxScaleRotation.x * _StreamScaling, 0.0) : VtxOffset;

        // Rotate across the opposite and adjacent sides
        VtxOffset = (TriangleVertexID != 0) ? mul(VtxOffset, CMath_GetRotationMatrix(VtxScaleRotation.y)) : VtxOffset;

        // Calculate final NDC position.
        float2 CellPosition = (VtxBasePos + VtxOffset) * TriangleSize;
        float2 FinalPos = CMath_UNORMtoSNORM_FLT2(CellPosition);

        /*
            Standard ReShade projection: Flip Y for top-down orientation:

            ID0 (0, 0) · · ID1 (1, 0)
            · · · · · · · ·
            · · · · · · ·
            · · · · · ·
            · · · · ·
            · · · ·
            · · ·
            · ·
            ID2 (0, 1)
        */
        Output.HPos = float4(FinalPos.x, -FinalPos.y, 0.0, 1.0);

        // Output texture coordinates.
        Output.Tex0 = Vertex;

        // For coloring in the PixelShader
        Output.Velocity = Velocity;
    }

    void PS_VectorStreaming(in VS2PS_Cell Input, out float4 Output : SV_Target)
    {
        // Get velocity.
        float2 Velocity = Input.Velocity * float2(1.0, -1.0);
        float DotVV = dot(Velocity, Velocity);
        float InverseMagnitude = rsqrt(DotVV + 1e-7);

        // Output color.
        // Calculate normalized velocity and map it to [0, 1] range for color output.
        // InverseMagnitude includes a small epsilon for numerical stability.
        Output.rg = CMath_SNORMtoUNORM_FLT2(Velocity.xy * InverseMagnitude);
        Output.b = 1.0 - dot(Output.rg, 0.5);

        float2 UV = CMath_UNORMtoSNORM_FLT2(Input.Tex0.xy);
        float2 ScaledUV = UV * float2(0.75, 3.0);
        Output.a = smoothstep(0.5, 0.0, length(ScaledUV));
    }
#else
    void PS_VectorShading(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleFlow, float4(Input.Tex0.xy, 0.0, _MipBias)).xy);

        // Encode vectors
        float3 VectorColors = normalize(float3(Vectors, 1e-3));
        VectorColors.xy = CMath_SNORMtoUNORM_FLT2(VectorColors.xy);
        VectorColors.z = sqrt(1.0 - saturate(dot(VectorColors.xy, VectorColors.xy)));
        VectorColors = normalize(VectorColors);

        // Renormalize motion vectors to take advantage of intensity
        float3 RenormalizedVectorColors = VectorColors / max(max(VectorColors.x, VectorColors.y), VectorColors.z);

        // Line Integral Convolution (LIC)
        float LIC = 0.0;
        float WeightSum = 0.0;

        [unroll]
        for (float i = 1.0; i < 4.0; i += 0.5)
        {
            float2 Offset = Vectors * i;
            LIC += tex2D(SampleNoiseTex, Input.Tex0 + Offset).r;
            LIC += tex2D(SampleNoiseTex, Input.Tex0 - Offset).r;
            WeightSum += 2.0;
        }

        // Normalize LIC
        LIC /= WeightSum;

        // Conditional output
        float3 OutputColor = 0.0;
        switch (_DisplayMode)
        {
            case 0:
                OutputColor = VectorColors;
                break;
            case 1:
                OutputColor = RenormalizedVectorColors;
                break;
            case 2:
                OutputColor = LIC;
                break;
            case 3:
                OutputColor = LIC * RenormalizedVectorColors;
                break;
            default:
                OutputColor = 0.0;
                break;
        }

        // RENDER
        #if defined(CSHADE_BLENDING)
            Output = float4(OutputColor.rgb, _CShade_AlphaFactor);
        #else
            Output = float4(OutputColor.rgb, 1.0);
        #endif
        CShade_Render(Output, Input.HPos.xy, Input.Tex0);
    }
#endif

void PS_GenerateNoise(CShade_VS2PS_Quad Input, out float Output : SV_TARGET0)
{
    Output = CMath_GetHash_FLT1(Input.HPos.xy, 0.0);
}

/* Techniques */

#define CREATE_PASS(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass NAME \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

#if !SHADER_VECTOR_STREAMING
    technique GenerateNoise <
        enabled = true;
        timeout = 1;
        hidden = true;
    >
    {
        pass GenerateNoise
        {
            VertexShader = CShade_VS_Quad;
            PixelShader = PS_GenerateNoise;
            RenderTarget0 = NoiseTex;
        }
    }
#endif

technique CShade_Flow
<
    ui_label = "CShade | Optical Flow";
    ui_tooltip = "Lucas-Kanade optical flow.";
>
{
    CREATE_PASS(Pyramid, CShade_VS_Quad, PS_Pyramid, TempTex1_RGB10A2)

    CREATE_PASS(LucasKanade4, CShade_VS_Quad, PS_LucasKanade4, TempTex5_RG16F)
    CREATE_PASS(LucasKanade3, CShade_VS_Quad, PS_LucasKanade3, TempTex4_RG16F)
    CREATE_PASS(LucasKanade2, CShade_VS_Quad, PS_LucasKanade2, TempTex3_RG16F)
    pass GetFineOpticalFlow
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_LucasKanade1;
        RenderTarget0 = FlowTex;
    }

    pass CopyFrame
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Copy;
        RenderTarget0 = PreviousFrameTex;
    }

    pass Median
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Median;
        RenderTarget0 = TempTex5_RG16F;
    }

    pass BilateralUpsample1
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample1;
        RenderTarget0 = TempTex4_RG16F;
    }

    pass BilateralUpsample2
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample2;
        RenderTarget0 = TempTex3_RG16F;
    }

    pass BilateralUpsample3
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample3;
        RenderTarget0 = TempTex2_RG16F;
    }

    pass Main
    {
        CBLEND_CREATE_STATES()

        #if SHADER_VECTOR_STREAMING
            VertexCount = (VTX_ROWS * VTX_COLUMNS) * VTX_PER_TRIANGLE;
            PrimitiveTopology = TRIANGLELIST;

            // Optional
            ClearRenderTargets = SHADER_VECTOR_STREAMING_CLEAR;

            VertexShader = VS_VectorStreaming;
            PixelShader = PS_VectorStreaming;
        #else
            VertexShader = CShade_VS_Quad;
            PixelShader = PS_VectorShading;
        #endif
    }
}
