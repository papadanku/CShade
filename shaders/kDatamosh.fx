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

uniform float _Time < source = "timer"; >;

uniform float _MipBias <
    ui_category = "Optical Flow";
    ui_label = "Mipmap Level";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
> = 0.0;

uniform float _BlendFactor <
    ui_category = "Optical Flow";
    ui_label = "Temporal Blending Weight";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 0.9;
> = 0.25;

uniform int _BlockSize <
    ui_category = "Datamosh";
    ui_label = "Block Size";
    ui_type = "slider";
    ui_min = 0;
    ui_max = 32;
> = 4;

uniform float _Entropy <
    ui_category = "Datamosh";
    ui_label = "Entropy";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.1;

uniform float _Contrast <
    ui_category = "Datamosh";
    ui_label = "Noise Contrast";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 4.0;
> = 0.1;

uniform float _Scale <
    ui_category = "Datamosh";
    ui_label = "Velocity Scale";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 2.0;
> = 1.0;

uniform float _Diffusion <
    ui_category = "Datamosh";
    ui_label = "Random Displacement";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 4.0;
> = 2.0;

#include "shared/cShadeHDR.fxh"
#include "shared/cBlend.fxh"

/*
    [Textures and samplers]
*/

CREATE_TEXTURE_POOLED(TempTex1_RGB10A2, BUFFER_SIZE_1, RGB10A2, 8)
CREATE_TEXTURE_POOLED(TempTex2_RG16F, BUFFER_SIZE_3, RG16F, 8)
CREATE_TEXTURE_POOLED(TempTex3_RG16F, BUFFER_SIZE_4, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex4_RG16F, BUFFER_SIZE_5, RG16F, 1)
CREATE_TEXTURE_POOLED(TempTex5_RG16F, BUFFER_SIZE_6, RG16F, 1)

CREATE_SAMPLER(SampleTempTex1, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex3, TempTex3_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex4, TempTex4_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SAMPLER(SampleTempTex5, TempTex5_RG16F, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_TEXTURE(PreviousFrameTex, BUFFER_SIZE_1, RGB10A2, 8)
CREATE_SAMPLER_LODBIAS(SamplePreviousFrameTex, PreviousFrameTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CREATE_SAMPLER_LODBIAS(SampleCurrentFrameTex, TempTex1_RGB10A2, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)

CREATE_TEXTURE(FlowTex, BUFFER_SIZE_3, RG16F, 8)
CREATE_SAMPLER_LODBIAS(SampleGuide, FlowTex, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP, -0.5)
CREATE_SAMPLER(SampleFilteredFlowTex, TempTex2_RG16F, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)

CREATE_TEXTURE(AccumTex, BUFFER_SIZE_0, R16F, 1)
CREATE_TEXTURE(FeedbackTex, BUFFER_SIZE_0, RGBA8, 1)
CREATE_SAMPLER(SampleAccumTex, AccumTex, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
CREATE_SRGB_SAMPLER(SampleSourceTex, CShade_ColorTex, SHADER_WARP_SAMPLING, SHADER_WARP_SAMPLING, LINEAR, MIRROR, MIRROR, MIRROR)
CREATE_SRGB_SAMPLER(SampleFeedbackTex, FeedbackTex, SHADER_WARP_SAMPLING, SHADER_WARP_SAMPLING, LINEAR, MIRROR, MIRROR, MIRROR)

/*
    [Pixel Shaders]
*/

float4 PS_Pyramid(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float3 Color = CColor_RGBtoSRGB(CShadeHDR_Tex2D_InvTonemap(CShade_SampleColorTex, Input.Tex0)).rgb;
    return float4(CColor_RGBtoSphericalRGB(Color), 1.0);
}

// Run Lucas-Kanade

float2 PS_LucasKanade4(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = 0.0;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

float2 PS_LucasKanade3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex5).xy;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

float2 PS_LucasKanade2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex4).xy;
    return CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex);
}

float4 PS_LucasKanade1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 Vectors = CMotionEstimation_GetSparsePyramidUpsample(Input.HPos.xy, Input.Tex0, SampleTempTex3).xy;
    return float4(CMotionEstimation_GetPixelPyLK(Input.HPos.xy, Input.Tex0, Vectors, SamplePreviousFrameTex, SampleCurrentFrameTex), 0.0, _BlendFactor);
}

/*
    Post-process filtering
*/

float4 PS_Copy(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(tex2D(SampleTempTex1, Input.Tex0.xy).rgb, 1.0);
}

float4 PS_Median(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetMedian(SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample1(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetSelfBilateralUpsampleXY(SampleTempTex5, SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample2(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetSelfBilateralUpsampleXY(SampleTempTex4, SampleGuide, Input.Tex0).rg, 0.0, 1.0);
}

float4 PS_Upsample3(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return float4(CBlur_GetSelfBilateralUpsampleXY(SampleTempTex3, SampleGuide, Input.Tex0).rg, 0.0, 1.0);
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

float4 PS_Accumulate(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float Quality = 1.0 - _Entropy;
    float3 Random = 0.0;

    // Motion vectors
    float2 MV = CMath_Float2_FP16ToNorm(tex2Dlod(SampleFilteredFlowTex, float4(Input.Tex0, 0.0, _MipBias)).xy);

    // Get motion blocks
    MV = GetMVBlocks(MV, Input.Tex0, Random);

    // Accumulates the amount of motion.
    float MVLength = length(MV);

    float4 OutputColor = 0.0;

    // Simple update
    float UpdateAcc = min(MVLength, _BlockSize) * 0.005;
    UpdateAcc += lerp(-Random.z, Random.z, Quality * 0.02);

    // Reset to random level
    float ResetAcc = (Random.z * 0.5) + Quality;

    // Reset if the amount of motion is larger than the block size.
    [branch]
    if (MVLength > _BlockSize)
    {
        OutputColor = float4((float3)ResetAcc, 0.0);
    }
    else
    {
        OutputColor = float4((float3)UpdateAcc, 1.0);
    }

    return OutputColor;
}

float4 PS_Datamosh(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    float2 TexSize = fwidth(Input.Tex0);
    const float2 DisplacementTexel = BUFFER_SIZE_0;
    const float Quality = 1.0 - _Entropy;
    float3 Random = 0.0;

    // Motion vectors
    float2 MV = CMath_Float2_FP16ToNorm(tex2Dlod(SampleFilteredFlowTex, float4(Input.Tex0, 0.0, _MipBias)).xy);

    // Get motion blocks
    MV = GetMVBlocks(MV, Input.Tex0, Random);

    // Get random motion
    float RandomMotion = RandUV(Input.Tex0 + length(MV));

    // Pixel coordinates -> Normalized screen space
    MV = NormalizeUV(MV, TexSize);

    // Displacement vector
    float Disp = tex2D(SampleAccumTex, Input.Tex0).r;

    // Color from the original image
    float4 Source = CShadeHDR_Tex2D_InvTonemap(SampleSourceTex, Input.Tex0);
    float4 Work = CShadeHDR_Tex2D_InvTonemap(SampleFeedbackTex, Input.Tex0 + MV);

    // Generate some pseudo random numbers.
    float4 Rand = frac(float4(1.0, 17.37135, 841.4272, 3305.121) * RandomMotion);

    // Generate noise patterns that look like DCT bases.
    float2 Frequency = Input.HPos.xy * (Rand.x * 80.0 / _Contrast);

    // Basis wave (vertical or horizontal)
    float DCT = cos(lerp(Frequency.x, Frequency.y, 0.5 < Rand.y));

    // Random amplitude (the high freq, the less amp)
    DCT *= Rand.z * (1.0 - Rand.x) * _Contrast;

    // Conditional weighting
    // DCT-ish noise: acc > 0.5
    float CW = (Disp > 0.5) * DCT;
    // Original image: rand < (Q * 0.8 + 0.2) && acc == 1.0
    CW = lerp(CW, 1.0, Rand.w < lerp(0.2, 1.0, Quality) * (Disp > (1.0 - 1e-3)));

    // If the conditions above are not met, choose work.
    return CBlend_OutputChannels(float4(lerp(Work.rgb, Source.rgb, CW), _CShadeAlphaFactor));
}

float4 PS_CopyColorTex(CShade_VS2PS_Quad Input) : SV_TARGET0
{
    return tex2D(CShade_SampleColorTex, Input.Tex0);
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
    ui_label = "CShade · Keijiro Takahashi · KinoDatamosh";
    ui_tooltip = "Keijiro Takahashi's image effect that simulates video compression artifacts.\n\n* Preprocessor Definitions *\n\nSHADER_DISPLACEMENT_SAMPLING - How the shader samples and processes displacement accumulation.\n\n\tOptions: LINEAR, POINT\n\nSHADER_WARP_SAMPLING - How the shader samples textures using in datamoshing's displacement pass.\n\n\tOptions: LINEAR, POINT";
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
        SRGBWriteEnable = WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Datamosh;
    }

    // Copy frame for feedback
    pass
    {
        SRGBWriteEnable = WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CopyColorTex;
        RenderTarget0 = FeedbackTex;
    }
}
