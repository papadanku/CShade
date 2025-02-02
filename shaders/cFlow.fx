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
    #define RENDER_VELOCITY_STREAMS 1
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
#endif

/*
    [Textures & Samplers]
*/

CREATE_TEXTURE_POOLED(TempTex1_RG16F, BUFFER_SIZE_1, RG16F, 3)
CREATE_TEXTURE_POOLED(TempTex2a_RG16F, BUFFER_SIZE_2, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex2b_RG16F, BUFFER_SIZE_2, RG16F, 8)
CREATE_TEXTURE_POOLED(TempTex3_RG16F, BUFFER_SIZE_3, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RG16F, BUFFER_SIZE_4, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RG16F, BUFFER_SIZE_5, RG16F, 1)

CREATE_SAMPLER(SampleTempTex1, TempTex1_RG16F, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex2b, TempTex2b_RG16F, LINEAR, MIRROR, MIRROR, MIRROR)

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
        Output.Velocity = CMath_HalfToNorm(tex2Dlod(SampleTempTex2b, float4(VelocityCoord, 0.0, _MipBias)).xy) / PixelSize;
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

CREATE_SAMPLER(SampleTempTex2a, TempTex2a_RG16F, LINEAR, MIRROR, MIRROR, MIRROR)

CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, MIRROR, MIRROR, MIRROR)

CREATE_TEXTURE(Tex2c, BUFFER_SIZE_2, RG16F, 8)
CREATE_SAMPLER(SampleTex2c, Tex2c, LINEAR, MIRROR, MIRROR, MIRROR)

CREATE_TEXTURE(OFlowTex, BUFFER_SIZE_2, RG16F, 1)
CREATE_SAMPLER(SampleOFlowTex, OFlowTex, LINEAR, MIRROR, MIRROR, MIRROR)

/*
    [Pixel Shaders]
*/

float2 PS_Normalize(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = CShade_BackBuffer2D(Input.Tex0).rgb;
    float2 Chroma = CColor_GetSphericalRG(Color).xy;
    return CMath_NormToHalf((Chroma * 2.0) - 1.0);
}

float2 PS_PrefilterHBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CBlur_GetPixelBlur(Input.Tex0, SampleTempTex1, true).rg;
}

float2 PS_PrefilterVBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return CBlur_GetPixelBlur(Input.Tex0, SampleTempTex2a, false).rg;
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
    return float4(CBlur_GetPixelBlur(Input.Tex0, SampleOFlowTex, true).rg, 0.0, 1.0);
}

float4 PS_PostfilterVBlur(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetPixelBlur(Input.Tex0, SampleTempTex2a, false).rg, 0.0, 1.0);
}

float4 PS_Shading(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = tex2Dlod(SampleTempTex2b, float4(Input.Tex0.xy, 0.0, _MipBias)).xy;
    Vectors.y *= -1.0;
    Vectors.xy /= fwidth(Input.Tex0.xy);
    float Magnitude = length(float3(Vectors, 1.0));

    float3 Display = 1.0;
    Display.xy = (Magnitude > 0.0) ? Vectors / Magnitude : 0.0;
    Display.xy = (Display.xy * 0.5) + 0.5;
    Display.z = 1.0 - dot(Display.xy, 0.5);

    return float4(Display, 1.0);
}

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
    CREATE_PASS(CShade_VS_Quad, PS_Normalize, TempTex1_RG16F)

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
            CBLEND_CREATE_STATES()

            VertexShader = CShade_VS_Quad;
            PixelShader = PS_Shading;
        }
    #endif
}
