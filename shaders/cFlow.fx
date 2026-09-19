#define CSHADE_FLOW

/*
    This shader calculates and visualizes optical flow using the Lucas-Kanade method. It analyzes motion between consecutive frames to generate motion vectors. The shader then visualizes these vectors using various display modes, including normalized or renormalized shading, and different Line Integral Convolution (LIC) visualizations. It also applies temporal smoothing to reduce flickering and offers control over the mipmap level for optical flow sampling.
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/* Preprocessor Definitions */

#ifndef SHADER_USE_CSHARES_MOTION_VECTORS
    #define SHADER_USE_CSHARES_MOTION_VECTORS 0
#endif

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

uniform float _MipBias <
    ui_text = "OPTICAL FLOW";
    ui_label = "Optical Flow Mipmap Level";
    ui_max = 3.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for sampling the optical flow map, affecting the detail and smoothness of the flow vectors.";
> = 0.0;

#if !SHADER_VECTOR_STREAMING
    uniform int _DisplayMode <
        ui_text = "VECTOR SHADING";
        ui_label = "Display Mode";
        ui_type = "combo";
        ui_items = "Shading / Normalized\0Shading / Renormalized\0Line Integral Convolution\0Line Integral Convolution / Colored\0";
        ui_tooltip = "Selects the visual output mode for optical flow.";
    > = 0;
#endif

#if SHADER_VECTOR_STREAMING
    uniform int _DisplayMode <
        ui_text = "VECTOR STREAMING";
        ui_items = "Output\0Debug · Quad\0";
        ui_label = "Display Mode";
        ui_type = "combo";
        ui_tooltip = "Controls how the contour effect is displayed, including various debug visualizations of gradients and magnitudes.";
    > = 0;

    uniform float _StreamScaling <
        ui_label = "Vector Motion Scaling";
        ui_max = 20.0;
        ui_min = 1.0;
        ui_type = "slider";
        ui_tooltip = "Amount of motion scaling applied to the displayed vectors.";
    > = 10.0;

    uniform float _VertexSize <
        ui_label = "Vector Vertex Size";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
        ui_tooltip = "Controls the size of the vector verticies.";
    > = 0.5;

    uniform float _MaskSize <
        ui_label = "Vector Mask Size";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
        ui_tooltip = "Controls the size of the vector mask.";
    > = 0.5;

    uniform float _MaskSmoothing <
        ui_label = "Vector Mask Smoothing";
        ui_max = 1.0;
        ui_min = 0.0;
        ui_type = "slider";
        ui_tooltip = "Controls the smoothing of the vector mask edges.";
    > = 0.5;
#endif

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

CSHADE_UI_PREPROCESSOR_GUIDE(
    "\nSHADER_OPTICAL_FLOW_SAMPLING - How the samples the optical flow map.\n\n\tOptions: LINEAR, POINT\n\nSHADER_VECTOR_STREAMING - Enables vector streaming visualization instead of shading.\n\n\tOptions: 0 (Disabled), 1 (Enabled)\n\nSHADER_VECTOR_STREAMING_ROWS - The number of rows used for vector streaming.\n\n\tOptions: Any integer value.\n\nSHADER_VECTOR_STREAMING_COLUMNS - The number of columns used for vector streaming.\n\n\tOptions: Any integer value.\n\nSHADER_VECTOR_STREAMING_CLEAR - Clears the render target before drawing vector streams. (0 = Disabled, 1 = Enabled)\n\n\tOptions: 0 (Disabled), 1 (Enabled)\n\n"
)

/* Textures & Samplers */

#if SHADER_USE_CSHARES_MOTION_VECTORS
    CSHADE_CREATE_TEXTURE(CShade_Mainframe_MotionVectors, CSHADE_BUFFER_SIZE_2, RG16F, 1)

    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex, CShade_Mainframe_MotionVectors, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
#else
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_1, CSHADE_BUFFER_SIZE_1, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RGB10A2_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)

    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_2_A, CSHADE_BUFFER_SIZE_2, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_A, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_A, CSHADE_BUFFER_SIZE_4, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_5_A, CSHADE_BUFFER_SIZE_5, RG16F, 1)

    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_2_B, CSHADE_BUFFER_SIZE_2, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_3_B, CSHADE_BUFFER_SIZE_3, RG16F, 1)
    CSHADE_CREATE_TEXTURE_POOLED(SharedTex_RG16F_4_B, CSHADE_BUFFER_SIZE_4, RG16F, 1)

    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Flow_2, CSHADE_BUFFER_SIZE_2, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Flow_3, CSHADE_BUFFER_SIZE_3, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Flow_4, CSHADE_BUFFER_SIZE_4, RGB10A2, 1)
    CSHADE_CREATE_TEXTURE(PreviousFrameTex_Flow_5, CSHADE_BUFFER_SIZE_5, RGB10A2, 1)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_1, SharedTex_RGB10A2_1, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_2, SharedTex_RGB10A2_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_3, SharedTex_RGB10A2_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_4, SharedTex_RGB10A2_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RGB10A2_5, SharedTex_RGB10A2_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_2_A, SharedTex_RG16F_2_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_3_A, SharedTex_RG16F_3_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_4_A, SharedTex_RG16F_4_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_5_A, SharedTex_RG16F_5_A, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_2_B, SharedTex_RG16F_2_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_3_B, SharedTex_RG16F_3_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleSharedTex_RG16F_4_B, SharedTex_RG16F_4_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Flow_2, PreviousFrameTex_Flow_2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Flow_3, PreviousFrameTex_Flow_3, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Flow_4, PreviousFrameTex_Flow_4, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SamplePreviousFrameTex_Flow_5, PreviousFrameTex_Flow_5, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_2, SharedTex_RG16F_2_B, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_3, SharedTex_RG16F_3_B, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_4, SharedTex_RG16F_4_B, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
    CSHADE_CREATE_SAMPLER(SampleMotionVectorTex_5, SharedTex_RG16F_5_A, SHADER_OPTICAL_FLOW_SAMPLING, SHADER_OPTICAL_FLOW_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
#endif

#if !SHADER_VECTOR_STREAMING
    CSHADE_CREATE_TEXTURE(NoiseTex, CSHADE_BUFFER_SIZE_0, R16, 0)

    CSHADE_CREATE_SAMPLER(SampleNoiseTex, NoiseTex, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
#endif

#if !SHADER_USE_CSHARES_MOTION_VECTORS

    /* Pixel Shaders: Pyramid */

    void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float4 Color = tex2Dlod(CShade_SampleColorTex, CShade_PadFloat2(Input.Tex0));
        Output.rgb = sqrt(Color.rgb);
        Output.a = 1.0;
    }

    void PS_PyramidLevel1(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_1, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    void PS_PyramidLevel2(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_2, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    void PS_PyramidLevel3(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_3, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    void PS_PyramidLevel4(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RGB10A2_4, Input.Tex0, PixelSize).rgb;
        Output.a = 1.0;
    }

    /* Pixel Shaders: Lucas-Kanade */

    void PS_LucasKanade4(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 Vectors = 0.0;
        float2 PixelSize = fwidth(Input.Tex0.xy);
        Output = CMotionEstimation_GetLucasKanade(true, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Flow_5, SampleSharedTex_RGB10A2_5);
    }

    void PS_LucasKanade3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_5_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Flow_4, SampleSharedTex_RGB10A2_4);
    }

    void PS_LucasKanade2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_4_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Flow_3, SampleSharedTex_RGB10A2_3);
    }

    void PS_LucasKanade1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, PixelSize, SampleSharedTex_RG16F_3_A);
        Output = CMotionEstimation_GetLucasKanade(false, Input.Tex0, PixelSize, Vectors, SamplePreviousFrameTex_Flow_2, SampleSharedTex_RGB10A2_2);
    }

    /* Pixel Shaders: Downsample */

    void PS_Downsample1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_2_A, Input.Tex0, PixelSize).xy;
    }

    void PS_Downsample2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_3_A, Input.Tex0, PixelSize).xy;
    }

    void PS_Downsample3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0);
        Output = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_4_A, Input.Tex0, PixelSize).xy;
    }

    /* Pixel Shaders: Upsample & Blit */

    void PS_CopyCoarse(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        Output = tex2Dlod(SampleSharedTex_RGB10A2_5, CShade_PadFloat2(Input.Tex0));
    }

    void PS_Upsample3_Copy3(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
    {
        Output0 = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_5_A, SampleSharedTex_RG16F_4_A, Input.Tex0);
        Output1 = tex2Dlod(SampleSharedTex_RGB10A2_4, CShade_PadFloat2(Input.Tex0));
    }

    void PS_Upsample2_Copy2(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
    {
        Output0 = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_4_B, SampleSharedTex_RG16F_3_A, Input.Tex0);
        Output1 = tex2Dlod(SampleSharedTex_RGB10A2_3, CShade_PadFloat2(Input.Tex0));
    }

    void PS_Upsample1_Copy1(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
    {
        Output0 = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_3_B, SampleSharedTex_RG16F_2_A, Input.Tex0);
        Output1 = tex2Dlod(SampleSharedTex_RGB10A2_2, CShade_PadFloat2(Input.Tex0));
    }

    float2 GetMotionVector(float4 Tex)
    {
        float2 MipLevels[4];
        MipLevels[0] = tex2Dlod(SampleMotionVectorTex_2, Tex).xy;
        MipLevels[1] = tex2Dlod(SampleMotionVectorTex_3, Tex).xy;
        MipLevels[2] = tex2Dlod(SampleMotionVectorTex_4, Tex).xy;
        MipLevels[3] = tex2Dlod(SampleMotionVectorTex_5, Tex).xy; // Fixed array index (0-3)

        // Expand the clamp range to cover 4 levels (0.0 -> 3.0)
        float Bias = clamp(_MipBias, 0.0, 3.0);

        [flatten]
        if (Bias <= 1.0)
        {
            // Smoothly lerp between Level 0 and Level 1 (bias: 0.0 -> 1.0)
            return lerp(MipLevels[0], MipLevels[1], Bias);
        }
        else if (Bias <= 2.0)
        {
            // Smoothly lerp between Level 1 and Level 2 (bias: 1.0 -> 2.0)
            return lerp(MipLevels[1], MipLevels[2], Bias - 1.0);
        }
        else
        {
            // Smoothly lerp between Level 2 and Level 3 (bias: 2.0 -> 3.0)
            return lerp(MipLevels[2], MipLevels[3], Bias - 2.0);
        }
    }

#endif

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
        // Enforce clamping here.
        float GVertexSize = min(_VertexSize, 1.0);

        float Pi2 = CMath_GetPi() * 2.0;

        // Identify which triangle and which corner of the triangle we are on.
        int TriangleID = Input.ID / VTX_PER_TRIANGLE;
        int TriangleVertexID = CMath_GetModulus_FLT1(Input.ID, VTX_PER_TRIANGLE);

        // Column and Row information.
        int Column = CMath_GetModulus_FLT1(TriangleID, VTX_COLUMNS);
        int Row = TriangleID / VTX_COLUMNS;
        int IsOddRow = CMath_GetModulus_FLT1(Row, 2);

        // Calculate our Grid size and Triangle size.
        float2 GridSize = max(float2(VTX_COLUMNS, VTX_ROWS), 1.0);

        // Calculate the Cell Origin.
        float2 VtxBasePos = float2(Column, Row);

        // We append some offsets to make the grid look more dynamic.
        float ShiftOdds = lerp(-0.25, 0.25, IsOddRow);
        VtxBasePos.x -= ShiftOdds;

        // Apply velocity to CellOffset.
        float4 VelocityTex = CShade_PadFloat2(VtxBasePos / GridSize);
        float2 Velocity = CMath_FP16toSNORM_FLT2(GetMotionVector(VelocityTex).xy);

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

        /*
            float2x2(cos, sin, -sin, cos) mapped to (x, y, -y, x)

            Now, why this works:
            - Normalizing the Motion Vector gives it a unit-length of 1, that moves around a 2D unit circle
            - Doing a cross-product of the Normal, cross(Normal, float3(0.0, 0.0, 1.0)), should give us the Tangent
            - We use the resulting Normal and Tangent vectors to construct a rotation matrix
        */

        // Calculate the Motion Vector's magnitude
        float2 VtxVector = -Velocity * GridSize;
        float VtxMagnitude = length(VtxVector);

        // Calculate the Motion Vector's direction (normal)
        // If VtxMagnitude is 0, we default to identity rotation (pointing right)
        float2 VtxNormal = (VtxMagnitude > 0.0) ? VtxVector / VtxMagnitude : float2(1.0, 0.0);

        // Initiate the rotation matrix
        float2x2 VtxRotationMatrix = float2x2(
             VtxNormal.x, VtxNormal.y,  // Normal
            -VtxNormal.y, VtxNormal.x   // Tangent
        );

        // Calculate the vertex directional information.
        float VtxScale = (TriangleVertexID == 1) ? VtxMagnitude * _StreamScaling : 1.0;

        VtxOffset = CMath_UNORMtoSNORM_FLT2(VtxOffset);
        VtxOffset.x *= VtxScale;
        VtxOffset *= GVertexSize;
        VtxOffset = mul(VtxOffset, VtxRotationMatrix);
        VtxOffset = CMath_SNORMtoUNORM_FLT2(VtxOffset);

        // Calculate final NDC position.
        float2 CellPosition = (VtxBasePos + VtxOffset) / GridSize;
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
        Output.Velocity = -Velocity;
    }

    void PS_VectorStreaming(in VS2PS_Cell Input, out float4 Output : SV_Target)
    {
        // Process velocity.
        float2 Velocity = Input.Velocity;
        float DotVV = dot(Velocity, Velocity);
        float SqrtDotVV = DotVV > 0.0 ? sqrt(DotVV) : 1.0;
        float FadeFactor = smoothstep(1e-5, 1e-3, SqrtDotVV);

        if (_DisplayMode == 0)
        {
            // Process vertex inputs.
            float2 TexSNORM = CMath_UNORMtoSNORM_FLT2(Input.Tex0.xy);

            // Process uniforms.
            float MaskSize = lerp(5.0, 1.0, saturate(_MaskSize));
            float MaskSmoothing = lerp(0.9, 0.0, saturate(_MaskSmoothing));
            float2 MaskUV = TexSNORM * float2(1.0, MaskSize);

            // Process alpha.
            Output.a = smoothstep(1.0, MaskSmoothing, length(MaskUV));
            Output.a = DotVV > 0.0 ? Output.a * FadeFactor : 0.0;

            if (CMath_GetOutOfBounds(Input.Tex0.xy) || (Output.a <= 0.0))
            {
                discard;
            }

            // Calculate normalized velocity and map it to [0, 1] range for color output.
            Output.rg = CMath_SNORMtoUNORM_FLT2(Velocity.xy / SqrtDotVV);
            Output.b = 1.0 - dot(Output.rg, 0.5);
        }
        else if (_DisplayMode == 1)
        {
            if (CMath_GetOutOfBounds(Input.Tex0.xy))
            {
                discard;
            }

            Output.rg = Input.Tex0.xy;
            Output.b = 1.0 - dot(Output.rg, 0.5);
            Output.a = DotVV > 0.0 ? FadeFactor : 0.0;
        }
        else
        {
            Output = float4(0.5, 0.5, 0.5, 0.5);
        }
    }
#else
    void PS_VectorShading(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
    {
        float2 PixelSize = fwidth(Input.Tex0.xy);
        float2 Vectors = CMath_FP16toSNORM_FLT2(GetMotionVector(CShade_PadFloat2(Input.Tex0.xy)).xy);

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
            LIC += tex2Dlod(SampleNoiseTex, CShade_PadFloat2(Input.Tex0 + Offset)).r;
            LIC += tex2Dlod(SampleNoiseTex, CShade_PadFloat2(Input.Tex0 - Offset)).r;
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

#define TEMPLATE_PASS(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass NAME \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

#define TEMPLATE_PASS_MRT2(NAME, VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET_0, RENDER_TARGET_1) \
    pass NAME \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET_0; \
        RenderTarget1 = RENDER_TARGET_1; \
    }

#if !SHADER_VECTOR_STREAMING
    technique GenerateNoise <
        enabled = true;
        timeout = 1;
        hidden = true;
        ui_tooltip = "Generates noise patterns for use in the shader.";
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

#if SHADER_USE_CSHARES_MOTION_VECTORS
    #define SHADER_UI_LABEL_EXT1 " & CShares"
#else
    #define SHADER_UI_LABEL_EXT1 ""
#endif

#if SHADER_VECTOR_STREAMING
    #define SHADER_UI_LABEL_EXT2 " (Streaming)"
#else
    #define SHADER_UI_LABEL_EXT2 " (Shading)"
#endif

#define SHADER_UI_LABEL "CShade" SHADER_UI_LABEL_EXT1 " | Optical Flow" SHADER_UI_LABEL_EXT2

technique CShade_Flow
<
    ui_label = SHADER_UI_LABEL;
    ui_tooltip = "Lucas-Kanade optical flow.";
>
{
    #if !SHADER_USE_CSHARES_MOTION_VECTORS
        // Prepare
        TEMPLATE_PASS(Pyramid, CShade_VS_Quad, PS_Pyramid, SharedTex_RGB10A2_1)

        // Construct Pyramid 1
        TEMPLATE_PASS(Pyramid1, CShade_VS_Quad, PS_PyramidLevel1, SharedTex_RGB10A2_2)
        TEMPLATE_PASS(Pyramid2, CShade_VS_Quad, PS_PyramidLevel2, SharedTex_RGB10A2_3)
        TEMPLATE_PASS(Pyramid3, CShade_VS_Quad, PS_PyramidLevel3, SharedTex_RGB10A2_4)
        TEMPLATE_PASS(Pyramid4, CShade_VS_Quad, PS_PyramidLevel4, SharedTex_RGB10A2_5)

        // Process Lucas-Kanade
        TEMPLATE_PASS(LucasKanade4, CShade_VS_Quad, PS_LucasKanade4, SharedTex_RG16F_5_A)
        TEMPLATE_PASS(LucasKanade3, CShade_VS_Quad, PS_LucasKanade3, SharedTex_RG16F_4_A)
        TEMPLATE_PASS(LucasKanade2, CShade_VS_Quad, PS_LucasKanade2, SharedTex_RG16F_3_A)
        TEMPLATE_PASS(LucasKanade1, CShade_VS_Quad, PS_LucasKanade1, SharedTex_RG16F_2_A)

        // Build Pyramid 2
        TEMPLATE_PASS(Downsample1, CShade_VS_Quad, PS_Downsample1, SharedTex_RG16F_3_A)
        TEMPLATE_PASS(Downsample2, CShade_VS_Quad, PS_Downsample2, SharedTex_RG16F_4_A)
        TEMPLATE_PASS(Downsample3, CShade_VS_Quad, PS_Downsample3, SharedTex_RG16F_5_A)

        // Apply Filtering
        TEMPLATE_PASS(CopyCoarse, CShade_VS_Quad, PS_CopyCoarse, PreviousFrameTex_Flow_5)
        TEMPLATE_PASS_MRT2(Upsample3_Copy3, CShade_VS_Quad, PS_Upsample3_Copy3, SharedTex_RG16F_4_B, PreviousFrameTex_Flow_4)
        TEMPLATE_PASS_MRT2(Upsample2_Copy2, CShade_VS_Quad, PS_Upsample2_Copy2, SharedTex_RG16F_3_B, PreviousFrameTex_Flow_3)
        TEMPLATE_PASS_MRT2(Upsample1_Copy1, CShade_VS_Quad, PS_Upsample1_Copy1, SharedTex_RG16F_2_B, PreviousFrameTex_Flow_2)
    #endif

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
