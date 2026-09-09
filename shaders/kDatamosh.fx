#define CSHADE_DATAMOSH

/*
    This shader implements a datamoshing effect, inspired by Keijiro Takahashi's work, to simulate video compression artifacts. It distorts and glithes the image by manipulating motion vectors and introducing calculated noise. The shader uses optical flow (Lucas-Kanade) to track movement and then applies controlled displacement, random pixel diffusion, and noise patterns resembling DCT bases. Users can adjust parameters such as block size, entropy (randomness), noise contrast, motion vector scale, and diffusion strength to customize the glitch aesthetic.
*/

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

/* Shader Options */

#ifndef SHADER_DISPLACEMENT_SAMPLING
    #define SHADER_DISPLACEMENT_SAMPLING POINT
#endif

#ifndef SHADER_WARP_SAMPLING
    #define SHADER_WARP_SAMPLING POINT
#endif

uniform float _Time < source = "timer"; ui_tooltip = "The shader's internal timer, used for time-based effects."; > ;

uniform int _BlockSize <
    ui_category = "Datamosh";
    ui_label = "Datamosh Block Size";
    ui_max = 32;
    ui_min = 0;
    ui_type = "slider";
    ui_tooltip = "Defines the size of the pixel blocks used for the datamoshing effect.";
> = 4;

uniform float _Entropy <
    ui_category = "Datamosh";
    ui_label = "Datamosh Randomness";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the level of randomness or corruption applied to the datamosh effect.";
> = 0.1;

uniform float _Contrast <
    ui_category = "Datamosh";
    ui_label = "Datamosh Noise Contrast";
    ui_max = 4.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Adjusts the contrast of the noise patterns generated for the datamosh effect.";
> = 0.1;

uniform float _Scale <
    ui_category = "Datamosh";
    ui_label = "Motion Vector Scale";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the scaling factor applied to motion vectors, influencing the intensity of displacement.";
> = 1.0;

uniform float _Diffusion <
    ui_category = "Datamosh";
    ui_label = "Random Pixel Displacement";
    ui_max = 4.0;
    ui_min = 0.0;
    ui_type = "slider";
    ui_tooltip = "Controls the amount of random displacement applied to pixels, contributing to the glitch effect.";
> = 2.0;

#define CSHADE_APPLY_AUTO_EXPOSURE 0
#define CSHADE_APPLY_ABBERATION 0
#include "shared/cShade.fxh"

CSHADE_UI_PREPROCESSOR_GUIDE(
    "\nSHADER_DISPLACEMENT_SAMPLING - How the shader samples and processes displacement accumulation.\n\n\tOptions: LINEAR, POINT\n\nSHADER_WARP_SAMPLING - How the shader samples textures using in datamoshing's displacement pass.\n\n\tOptions: LINEAR, POINT\n\n"
)

/*
    [Textures and samplers]
*/

CSHADE_CREATE_SRGB_SAMPLER(SampleSourceTex, CShade_ColorTex, SHADER_WARP_SAMPLING, SHADER_WARP_SAMPLING, LINEAR, MIRROR, MIRROR, MIRROR)

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

CSHADE_CREATE_SAMPLER(SampleMotionVectorTex1, SharedTex_RG16F_4_B, LINEAR, LINEAR, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SAMPLER(SampleMotionVectorTex2, SharedTex_RG16F_4_B, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)

CSHADE_CREATE_TEXTURE(AccumulationTex_Datamosh, CSHADE_BUFFER_SIZE_0, R16F, 1)
CSHADE_CREATE_TEXTURE(FeedbackTex_Datamosh, CSHADE_BUFFER_SIZE_0, RGBA8, 1)
CSHADE_CREATE_SAMPLER(SampleAccumulationTex, AccumulationTex_Datamosh, SHADER_DISPLACEMENT_SAMPLING, SHADER_DISPLACEMENT_SAMPLING, LINEAR, CLAMP, CLAMP, CLAMP)
CSHADE_CREATE_SRGB_SAMPLER(SampleFeedbackTex, FeedbackTex_Datamosh, SHADER_WARP_SAMPLING, SHADER_WARP_SAMPLING, LINEAR, MIRROR, MIRROR, MIRROR)

/* Pixel Shaders: Pyramid */

void PS_Pyramid(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    float4 Color = tex2D(CShade_SampleColorTex, Input.Tex0);
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

/* Pixel Shaders: Downsample & Blit */

void PS_CopyMotionLevel2(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(SampleSharedTex_RGB10A2_2, Input.Tex0.xy);
}

void PS_MotionLevel1(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
{
    float2 PixelSize = fwidth(Input.Tex0);
    Output0 = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_2_A, Input.Tex0, PixelSize).xy;
    Output1 = tex2D(SampleSharedTex_RGB10A2_3, Input.Tex0);
}

void PS_MotionLevel2(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
{
    float2 PixelSize = fwidth(Input.Tex0);
    Output0 = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_3_A, Input.Tex0, PixelSize).xy;
    Output1 = tex2D(SampleSharedTex_RGB10A2_4, Input.Tex0);
}

void PS_MotionLevel3(CShade_VS2PS_Quad Input, out float2 Output0 : SV_TARGET0, out float4 Output1 : SV_TARGET1)
{
    float2 PixelSize = fwidth(Input.Tex0);
    Output0 = CBlur_DownsampleBox3x3(SampleSharedTex_RG16F_4_A, Input.Tex0, PixelSize).xy;
    Output1 = tex2D(SampleSharedTex_RGB10A2_5, Input.Tex0);
}

/* Pixel Shaders: Filtering */

void PS_Upsample3(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_5_A, SampleSharedTex_RG16F_4_A, Input.Tex0);
}

void PS_Upsample2(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_4_B, SampleSharedTex_RG16F_3_A, Input.Tex0);
}

void PS_Upsample1(CShade_VS2PS_Quad Input, out float2 Output : SV_TARGET0)
{
    Output = CBlur_GetSideWindowBilateralUpsample_FLT2(SampleSharedTex_RG16F_3_B, SampleSharedTex_RG16F_2_A, Input.Tex0);
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
    float4 MVTex = float4(Input.Tex0, 0.0, 0.0);
    float2 MV = CMath_FP16toSNORM_FLT2(tex2Dlod(SampleMotionVectorTex1, MVTex).xy);

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
    float Disp = tex2D(SampleAccumulationTex, Tex).r;

    // Color from the original image
    float4 Work = tex2D(SampleFeedbackTex, Tex + MV);

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
    float4 Base = tex2D(SampleSourceTex, Input.Tex0);
    float4 MVTex = float4(Input.Tex0, 0.0, 0.0);
    float2 MV = CMath_FP16toSNORM_FLT2(tex2Dlod(SampleMotionVectorTex2, MVTex).xy);
    float4 Datamosh = GetDataMosh(Base, MV, Input.HPos.xy, Input.Tex0, TexSize);

    // RENDER
    #if defined(CSHADE_BLENDING)
        Output = float4(Datamosh.rgb, _CShade_AlphaFactor);
    #else
        Output = float4(Datamosh.rgb, 1.0);
    #endif
    CShade_Render(Output, Input.HPos.xy, Input.Tex0);
}

void PS_CopyBackBuffer(CShade_VS2PS_Quad Input, out float4 Output : SV_TARGET0)
{
    Output = tex2D(CShade_SampleColorTex, Input.Tex0);
}

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

technique CShade_KinoDatamosh
<
    ui_label = "CShade | KinoDatamosh";
    ui_tooltip = "Keijiro Takahashi's image effect that simulates video compression artifacts.";
>
{
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
    TEMPLATE_PASS(MotionLevel1, CShade_VS_Quad, PS_LucasKanade1, SharedTex_RG16F_2_A)

    // Build Pyramid 2
    TEMPLATE_PASS(Copy, CShade_VS_Quad, PS_CopyMotionLevel2, PreviousFrameTex_Flow_2)
    TEMPLATE_PASS_MRT2(MotionLevel2, CShade_VS_Quad, PS_MotionLevel1, SharedTex_RG16F_3_A, PreviousFrameTex_Flow_3)
    TEMPLATE_PASS_MRT2(MotionLevel3, CShade_VS_Quad, PS_MotionLevel2, SharedTex_RG16F_4_A, PreviousFrameTex_Flow_4)
    TEMPLATE_PASS_MRT2(MotionLevel4, CShade_VS_Quad, PS_MotionLevel3, SharedTex_RG16F_5_A, PreviousFrameTex_Flow_5)

    // Apply Filtering
    TEMPLATE_PASS(BilateralUpsample3, CShade_VS_Quad, PS_Upsample3, SharedTex_RG16F_4_B)
    TEMPLATE_PASS(BilateralUpsample2, CShade_VS_Quad, PS_Upsample2, SharedTex_RG16F_3_B)
    TEMPLATE_PASS(BilateralUpsample1, CShade_VS_Quad, PS_Upsample1, SharedTex_RG16F_2_B)

    // Datamoshing
    pass Accumulate
    {
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = ONE;
        DestBlend = SRCALPHA; // The result about to accumulate

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Accumulate;
        RenderTarget0 = AccumulationTex_Datamosh;
    }

    pass Datamosh
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;
        CBLEND_CREATE_STATES()

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_Main;
    }

    // Copy frame for feedback
    pass CopyBackbuffer
    {
        SRGBWriteEnable = CSHADE_WRITE_SRGB;

        VertexShader = CShade_VS_Quad;
        PixelShader = PS_CopyBackBuffer;
        RenderTarget0 = FeedbackTex_Datamosh;
    }
}
