#define CSHADE_DATAMOSH

/*
    This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.

    In jurisdictions that recognize copyright laws, the author or authors
    of this software dedicate any and all copyright interest in the
    software to the public domain. We make this dedication for the benefit
    of the public at large and to the detriment of our heirs and
    successors. We intend this dedication to be an overt act of
    relinquishment in perpetuity of all present and future rights to this
    software under copyright law.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.

    For more information, please refer to <http://unlicense.org/>
*/

#include "shared/cColor.fxh"
#include "shared/cBlur.fxh"
#include "shared/cMotionEstimation.fxh"

/*
    [Shader Options]
*/

#ifndef SHADER_DISPLACEMENT_SAMPLING
    #define SHADER_DISPLACEMENT_SAMPLING POINT
#endif

#ifndef SHADER_WARP_SAMPLING
    #define SHADER_WARP_SAMPLING POINT
#endif

uniform float _Time < source = "timer"; ui_tooltip = "The shader's internal timer, used for time-based effects."; > ;

uniform float _MipBias <
    ui_category = "Main Shader / Optical Flow";
    ui_label = "Mipmap Level for Optical Flow";
    ui_max = 7.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the mipmap level used for texture sampling in optical flow calculations, affecting the level of detail.";
> = 0.0;

uniform float _BlendFactor <
    ui_category = "Main Shader / Optical Flow";
    ui_label = "Temporal Smoothing Factor";
    ui_max = 0.9;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the amount of temporal smoothing applied to the motion vectors, reducing flickering in the optical flow.";
> = 0.25;

uniform int _BlockSize <
    ui_category = "Main Shader / Datamosh";
    ui_label = "Datamosh Block Size";
    ui_max = 32;
    ui_min = 0;
    ui_type = "slider";
    ui_tooltip = "Defines the size of the pixel blocks used for the datamoshing effect.";
> = 4;

uniform float _Entropy <
    ui_category = "Main Shader / Datamosh";
    ui_label = "Datamosh Randomness";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the level of randomness or corruption applied to the datamosh effect.";
> = 0.1;

uniform float _Contrast <
    ui_category = "Main Shader / Datamosh";
    ui_label = "Datamosh Noise Contrast";
    ui_max = 4.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the contrast of the noise patterns generated for the datamosh effect.";
> = 0.1;

uniform float _Scale <
    ui_category = "Main Shader / Datamosh";
    ui_label = "Motion Vector Scale";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the scaling factor applied to motion vectors, influencing the intensity of displacement.";
> = 1.0;

uniform float _Diffusion <
    ui_category = "Main Shader / Datamosh";
    ui_label = "Random Pixel Displacement";
    ui_max = 4.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the amount of random displacement applied to pixels, contributing to the glitch effect.";
> = 2.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

uniform int _ShaderPreprocessorGuide <
    ui_category = "Preprocessor Guide / Shader";
    ui_category_closed = false;
    ui_label = " ";
    ui_text = "\nSHADER_DISPLACEMENT_SAMPLING - How the shader samples and processes displacement accumulation.\n\n\tOptions: LINEAR, POINT\n\nSHADER_WARP_SAMPLING - How the shader samples textures using in datamoshing's displacement pass.\n\n\tOptions: LINEAR, POINT\n\n";
    ui_type = "radio";
> = 0;

/*
    [Textures and samplers]
*/

CSHADE_CSHADE_CREATE_TEXTURE_POOLED(TempTex1_RGB10A2, CSHADE_BUFFER_SIZE_1, RGB10A2, 8)
CSHADE_CSHADE_CREATE_TEXTURE_POOLED(TempTex2_RG16F, CSHADE_BUFFER_SIZE_3, RG16F, 8)
CSHADE_CSHADE_CREATE_TEXTURE_POOLED(TempTex3_RG16F, CSHADE_BUFFER_SIZE_4, RG16F, 1)
CSHADE_CSHADE_CREATE_TEXTURE_POOLED(TempTex4_RG16F, CSHADE_BUFFER_SIZE_5, RG16F, 1)
CSHADE_CSHADE_CREATE_TEXTURE_POOLED(TempTex5_RG16F, CSHADE_BUFFER_SIZE_6, RG16F, 1)

CSHADE_CREATE_SAMPLER(SampleTempTex1, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CSHADE_CREATE_TEXTURE(PreviousFrameTex, CSHADE_BUFFER_SIZE_1, RGB10A2, 8)
CSHADE_CSHADE_CREATE_SAMPLER_LODBIAS(SamplePreviousFrameTex, PreviousFrameTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CSHADE_CSHADE_CREATE_SAMPLER_LODBIAS(SampleCurrentFrameTex, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

CSHADE_CREATE_TEXTURE(FlowTex, CSHADE_BUFFER_SIZE_3, RG16F, 8)
CSHADE_CSHADE_CREATE_SAMPLER_LODBIAS(SampleGuide, FlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CSHADE_CREATE_SAMPLER(SampleFilteredFlowTex, TempTex2_RG16F, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)

CSHADE_CREATE_TEXTURE(AccumTex, CSHADE_BUFFER_SIZE_0, R16F, 1)
CSHADE_CREATE_TEXTURE(FeedbackTex, CSHADE_BUFFER_SIZE_0, RGBA8, 1)
CSHADE_CREATE_SAMPLER(SampleAccumTex, AccumTex, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SRGB_SAMPLER(SampleSourceTex, CShade_ColorTex, SHADER_WARP_SAMPLING, SHADER_WARP_SAMPLING, LINEAR, MIRROR, MIRROR, MIRROR)
CSHADE_CREATE_SRGB_SAMPLER(SampleFeedbackTex, FeedbackTex, SHADER_WARP_SAMPLING, SHADER_WARP_SAMPLING, LINEAR, MIRROR, MIRROR, MIRROR)

/*
    [Pixel Shaders]
*/

void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = CShadeHDR_GetBackBuffer(CShade_SampleColorTex, Input.Tex0);
    float3 LogColor = CColor_EncodeLogC(Color.rgb) / CColor_EncodeLogC(1.0);

    float Sum = dot(LogColor, 1.0);
    float3 Ratio = abs(Sum) > 0.0 ? LogColor / Sum : 1.0 / 3.0;
    float MaxRatio = max(Ratio.r, max(Ratio.g, Ratio.b));
    float MaxColor = max(LogColor.r, max(LogColor.g, LogColor.b));

    Output.xy = MaxRatio > 0.0 ? Ratio.xy / MaxRatio : 1.0;
    Output.z = MaxColor;
    Output.w = 1.0;
}

// Run Lucas-Kanade

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

/*
    Post-process filtering
*/

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

// Datamosh

// [-1.0, 1.0] -> [Width, Height]
float2 UnnormalizeMV(float2 Vectors, float2 ImageSize)
{
    return Vectors / abs(ImageSize);
}

// [Width, Height] -> [-1.0, 1.0]
float2 NormalizeUV(float2 Vectors, float2 ImageSize)
{
    return clamp(Vectors * abs(ImageSize), -1.0, 1.0);
}

float RandUV(float2 Tex)
{
    float f = dot(float2(12.9898, 78.233), Tex);
    return frac(43758.5453 * sin(f));
}

float2 GetMVBlocks(float2 MV, float2 Tex, out float3 Random)
{
    float2 TexSize = fwidth(Tex);
    float2 Time = float2(_Time, 0.0);

    // Random numbers
    Random.x = RandUV(Tex.xy + Time.xy);
    Random.y = RandUV(Tex.xy + Time.yx);
    Random.z = RandUV(Tex.yx - Time.xx);

    // Normalized screen space -> Pixel coordinates
    MV = UnnormalizeMV(MV * _Scale, TexSize);

    // Small random displacement (diffusion)
    MV += (Random.xy - 0.5)  * _Diffusion;

    // Pixel perfect snapping
    return round(MV);
}

void PS_Accumulate(CShade_VS2PS_Quad Input, out float4 Accumulation : SV_TARGET0)
{
    float Quality = 1.0 - _Entropy;
    float3 Random = 0.0;

    // Motion vectors
    float2 MV = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleFilteredFlowTex, float4(Input.Tex0, 0.0, _MipBias)).xy);

    // Get motion blocks
    MV = GetMVBlocks(MV, Input.Tex0, Random);

    // Accumulates the amount of motion.
    float MVLength = length(MV);

    // Simple update
    float UpdateAcc = min(MVLength, _BlockSize) * 0.005;
    UpdateAcc += lerp(-Random.z, Random.z, Quality * 0.02);

    // Reset to random level
    float ResetAcc = (Random.z * 0.5) + Quality;

    // Reset if the amount of motion is larger than the block size.
    [branch]
    if (MVLength > _BlockSize)
    {
        Accumulation.rgb = ResetAcc;
        Accumulation.a = 0.0;
    }
    else
    {
        Accumulation.rgb = UpdateAcc;
        Accumulation.a = 1.0;
    }
}

float4 GetDataMosh(float4 Base, float2 MV, float2 Pos, float2 Tex, float2 Delta)
{
    const float Quality = 1.0 - _Entropy;

    // Initialize data
    float3 Random = 0.0;

    // Get motion blocks
    MV = GetMVBlocks(MV, Tex, Random);

    // Get random motion
    float RandomMotion = RandUV(Tex + length(MV));

    // Pixel coordinates -> Normalized screen space
    MV = NormalizeUV(MV, Delta);

    // Displacement vector
    float Disp = tex2D(SampleAccumTex, Tex).r;

    // Color from the original image
    float4 Work = CShadeHDR_GetBackBuffer(SampleFeedbackTex, Tex + MV);

    // Generate some pseudo random numbers.
    float4 Rand = frac(float4(1.0, 17.37135, 841.4272, 3305.121) * RandomMotion);

    // Generate noise patterns that look like DCT bases.
    float2 Frequency = Pos.xy * (Rand.x * 80.0 / _Contrast);

    // Basis wave (vertical or horizontal)
    float DCT = cos(lerp(Frequency.x, Frequency.y, 0.5 < Rand.y));

    // Random amplitude (the high freq, the less amp)
    DCT *= Rand.z * (1.0 - Rand.x) * _Contrast;

    // Conditional weighting
    // DCT-ish noise: acc > 0.5
    float CW = (Disp > 0.5) * DCT;
    // Original image: rand < (Q * 0.8 + 0.2) && acc == 1.0
    CW = lerp(CW, 1.0, Rand.w < lerp(0.2, 1.0, Quality) * (Disp > (1.0 - 1e-3)));

    return lerp(Work, Base, CW);
}

void PS_Main(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float2 TexSize = fwidth(Input.Tex0);
    float4 Base = CShadeHDR_GetBackBuffer(SampleSourceTex, Input.Tex0);
    float2 MV = CMath_FLT16toSNORM_FLT2(tex2Dlod(SampleFilteredFlowTex, float4(Input.Tex0, 0.0, _MipBias)).xy);
    float4 Datamosh = GetDataMosh(Base, MV, Input.HPos, Input.Tex0, TexSize);

    Output = CBlend_OutputChannels(Datamosh.rgb, _CShade_AlphaFactor);
}

void PS_CopyBackBuffer(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(CShade_SampleColorTex, Input.Tex0);
}

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass \
    { \
        VertexShader = VERTEX_SHADER; \
        PixelShader = PIXEL_SHADER; \
        RenderTarget0 = RENDER_TARGET; \
    }

technique CShade_KinoDatamosh
<
    ui_label = "CShade / Keijiro Takahashi / KinoDatamosh";
    ui_tooltip = "Keijiro Takahashi's image effect that simulates video compression artifacts.";
>
{
    // Normalize current frame
    CREATE_PASS(CShade_VS_Quad, PS_Pyramid, TempTex1_RGB10A2)

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
        RenderTarget0 = FlowTex;
    }

    pass Copy
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

    pass BilateralUpsample
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample1;
        RenderTarget0 = TempTex4_RG16F;
    }

    pass BilateralUpsample
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample2;
        RenderTarget0 = TempTex3_RG16F;
    }

    pass BilateralUpsample
    {
        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Upsample3;
        RenderTarget0 = TempTex2_RG16F;
    }

    // Datamoshing
    pass
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = ONE;
        DestBlend = SRCALPHA; // The result about to accumulate

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Accumulate;
        RenderTarget0 = AccumTex;
    }

    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }

    // Copy frame for feedback
    pass
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CopyBackBuffer;
        RenderTarget0 = FeedbackTex;
    }
}
