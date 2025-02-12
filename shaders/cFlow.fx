#define CSHADE_FLOW

/*
    MIT License

    Copyright (c) 2016 Thomas Diewald

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/*
    [Shader Options]
*/

#ifndef RENDER_VELOCITY_STREAMS
    #define RENDER_VELOCITY_STREAMS 0
#endif

#if RENDER_VELOCITY_STREAMS
    #ifndef VERTEX_SPACING
        #define VERTEX_SPACING 16
    #endif
    #ifndef RENDER_OVER_BUFFER
        #define RENDER_OVER_BUFFER 1
    #endif

    #define LINES_X uint(BUFFER_WIDTH / VERTEX_SPACING)
    #define LINES_Y uint(BUFFER_HEIGHT / VERTEX_SPACING)
    #define NUM_LINES (LINES_X * LINES_Y)
    #define SPACE_X (BUFFER_WIDTH / LINES_X)
    #define SPACE_Y (BUFFER_HEIGHT / LINES_Y)
    #define VELOCITY_SCALE (SPACE_X + SPACE_Y) * 1
#endif

uniform float _MipBias <
    ui_label = "Mipmap Bias";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
> = 0.0;

uniform float _BlendFactor <
    ui_label = "Temporal Blending Factor";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 0.9;
> = 0.45;

#include "shared/cShadeHDR.fxh"
#if !RENDER_VELOCITY_STREAMS
    #include "shared/cBlend.fxh"

    #ifndef RENDER_LINEAR_SAMPLED_FLOW
        #define RENDER_LINEAR_SAMPLED_FLOW 0
    #endif
#endif

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex1_RG8, BUFFER_SIZE_1, RG8, 8)
CREATE_TEXTURE_POOLED(TempTex2a_RG16F, BUFFER_SIZE_3, RG16F, 8)
CREATE_TEXTURE_POOLED(TempTex2b_RG16F, BUFFER_SIZE_3, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex3_RG16F, BUFFER_SIZE_4, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RG16F, BUFFER_SIZE_5, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RG16F, BUFFER_SIZE_6, RG16F, 1)

CREATE_SAMPLER(SampleTempTex1, TempTex1_RG8, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex2a, TempTex2a_RG16F, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex2b, TempTex2b_RG16F, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)

CREATE_TEXTURE(Tex2c, BUFFER_SIZE_3, RG8, 8)
CREATE_SAMPLER(SampleTex2c, Tex2c, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)

CREATE_TEXTURE(OFlowTex, BUFFER_SIZE_3, RG16F, 1)
CREATE_SAMPLER(SampleOFlowTex, OFlowTex, LINEAR, LINEAR, LINEAR, MIRROR, MIRROR, MIRROR)
#if !RENDER_VELOCITY_STREAMS
    #if RENDER_LINEAR_SAMPLED_FLOW
        #define FLOW_SAMPLER_FILTER LINEAR
    #else
        #define FLOW_SAMPLER_FILTER POINT
    #endif

    CREATE_SAMPLER(SampleFlow, TempTex2a_RG16F, FLOW_SAMPLER_FILTER, FLOW_SAMPLER_FILTER, LINEAR, MIRROR, MIRROR, MIRROR)
#endif

struct VS2PS_Streaming
{
    float4 HPos : SV_POSITION;
    float2 Velocity : TEXCOORD0;
};

#if RENDER_VELOCITY_STREAMS
    VS2PS_Streaming VS_Streaming(CShade_APP2VS Input)
    {
        VS2PS_Streaming Output;

        int LineID = Input.ID / 2; // Line Index
        int VertexID = Input.ID % 2; // Vertex Index within the line (0 = start, 1 = end)

        // Get Row (x) and Column (y) position
        int Row = LineID / LINES_X;
        int Column = LineID - LINES_X * Row;

        // Compute origin (line-start)
        const float2 Spacing = float2(SPACE_X, SPACE_Y);
        float2 Offset = Spacing * 0.5;
        float2 Origin = Offset + float2(Column, Row) * Spacing;

        // Get velocity from texture at origin location
        const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
        float2 VelocityCoord;
        VelocityCoord.x = Origin.x * PixelSize.x;
        VelocityCoord.y = 1.0 - (Origin.y * PixelSize.y);
        Output.Velocity = CMath_FP16ToNorm(tex2Dlod(SampleTempTex2b, float4(VelocityCoord, 0.0, _MipBias)).xy) / PixelSize;
        Output.Velocity.y *= -1.0;

        // Scale velocity
        float2 Direction = Output.Velocity * VELOCITY_SCALE;
        float Length = length(float3(Direction, 1.0));
        Direction = Direction * rsqrt(Length * 1e-1);

        // Color for fragmentshader
        Output.Velocity = Direction;

        // Compute current vertex position (based on VertexID)
        float2 VertexPosition = 0.0;

        // Lines: Velocity direction
        VertexPosition = Origin + (Direction * VertexID);

        // Finish vertex position
        float2 VertexPositionNormal = (VertexPosition + 0.5) * PixelSize; // [0, 1]
        Output.HPos = float4((VertexPositionNormal * 2.0) - 1.0, 0.0, 1.0); // ndc: [-1, +1]

        return Output;
    }
#endif

float4 PS_Streaming(VS2PS_Streaming Input) : SV_TARGET0
{
    float2 Velocity = Input.Velocity;
    float3 Display = 0.0;
    Display.rg = (Velocity * 0.5) + 0.5;
    Display.b = 1.0 - dot(Display.rg, 0.5);
    return float4(Display, 1.0);
}

/*
    [Pixel Shaders]
*/

float2 PS_Normalize(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0).rgb;
    return CColor_GetSphericalRG(Color).xy;
}

// Run Lucas-Kanade

float2 PS_LucasKanade4(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = 0.0;
    return CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float2 PS_LucasKanade3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetDilatedPyramidUpsample(SampleTempTex5, Input.Tex0).xy;
    return CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float2 PS_LucasKanade2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetDilatedPyramidUpsample(SampleTempTex4, Input.Tex0).xy;
    return CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
}

float4 PS_LucasKanade1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetDilatedPyramidUpsample(SampleTempTex3, Input.Tex0).xy;
    float2 Flow = CMotionEstimation_GetPixelPyLK(Input.Tex0, Vectors, SampleTex2c, SampleTempTex1);
    return float4(Flow, 0.0, _BlendFactor);
}

/*
    Postfilter median
*/

// We use MRT to immeduately copy the current blurred frame for the next frame
float4 PS_PostMedian0(CShade_VS2PS_Quad Input, out float4 Copy : SV_TARGET0) : SV_TARGET1
{
    Copy = tex2D(SampleTempTex1, Input.Tex0.xy);
    return float4(CBlur_GetMedian(SampleOFlowTex, Input.Tex0, 3.0, true).rg, 0.0, 1.0);
}

float4 PS_PostMedian1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetMedian(SampleTempTex2b, Input.Tex0, 2.0, true).rg, 0.0, 1.0);
}

float4 PS_PostMedian2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetMedian(SampleTempTex2a, Input.Tex0, 1.0, true).rg, 0.0, 1.0);
}

float4 PS_PostMedian3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetMedian(SampleTempTex2b, Input.Tex0, 0.0, true).rg, 0.0, 1.0);
}

#if !RENDER_VELOCITY_STREAMS
    float4 PS_Shading(CShade_VS2PS_Quad Input) : SV_TARGET0
    {
        float2 Vectors = CMath_FP16ToNorm(tex2Dlod(SampleFlow, float4(Input.Tex0.xy, 0.0, _MipBias)).xy);
        Vectors.xy /= fwidth(Input.Tex0.xy);
        Vectors.y *= -1.0;
        float Magnitude = length(float3(Vectors, 1.0));

        float3 Display = 1.0;
        Display.xy = (Magnitude > 0.0) ? Vectors / Magnitude : 0.0;
        Display.xy = (Display.xy * 0.5) + 0.5;
        Display.z = 1.0 - dot(Display.xy, 0.5);

        return float4(Display, 1.0);
    }
#endif

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_Flow < ui_tooltip = "Lucas-Kanade optical flow"; >
{
    // Normalize current frame
    CREATE_PASS(CShade_VS_Quad, PS_Normalize, TempTex1_RG8)

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
    pass MRT_CopyAndMedian
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_PostMedian0;
        RenderTarget1 = TempTex2b_RG16F;
        RenderTarget0 = Tex2c;
    }

    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_PostMedian1;
        RenderTarget0 = TempTex2a_RG16F;
    }

    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_PostMedian2;
        RenderTarget0 = TempTex2b_RG16F;
    }

    pass
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_PostMedian3;
        RenderTarget0 = TempTex2a_RG16F;
    }

    #if RENDER_VELOCITY_STREAMS
        pass
        {
            PrimitiveTopology = LINELIST;
            VertexCount = NUM_LINES * 2;
            VertexShader = VS_Streaming;
            PixelShader = PS_Streaming;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = ONE;
            DestBlend = ZERO;
        }
    #else
        pass
        {
            SRGBWriteEnable = WRITE_SRGB;
            CBLEND_CREATE_STATES()

            VertexShader = CShade_VS_Quad;
            PixelShader = PS_Shading;
        }
    #endif
}
