
/*
    This header file manages the conversion of SDR (Standard Dynamic Range) input colors back to HDR (High Dynamic Range) for consistent processing within the CShade pipeline. It provides a configurable inverse tonemapping operator, allowing shaders to correctly interpret and handle color data from the backbuffer, especially when the original scene was rendered in SDR. This ensures that HDR-aware effects can operate on an appropriate dynamic range, preventing clipping or incorrect color reproduction.
*/

#include "cShade.fxh"
#include "cColor.fxh"

#if !defined(INCLUDE_CSHADE_HDR)
    #define INCLUDE_CSHADE_HDR

    uniform int _CShade_InverseTonemapper <
        ui_category_closed = true;
        ui_category = "Pipeline / Input / Pre-Processing";
        ui_label = "Inverse Tonemapping Operator";
        ui_tooltip = "Selects an inverse tonemap operator to convert SDR colors back to HDR for processing, affecting how the backbuffer is sampled.";
        ui_type = "combo";
        ui_items = "None\0Reinhard [Inverse]\0Reinhard Squared [Inverse]\0AMD Resolve [Inverse]\0Logarithmic C [Decode]\0";
    > = 0;

    float4 CShadeHDR_GetBackBuffer(sampler Source, float2 Tex)
    {
        return CColor_ApplyInverseTonemap(tex2D(Source, Tex), _CShade_InverseTonemapper);
    }

    float4 CShadeHDR_Tex2Dlod_TonemapToRGB(sampler Source, float4 Tex)
    {
        return CColor_ApplyInverseTonemap(tex2Dlod(Source, Tex), _CShade_InverseTonemapper);
    }

#endif