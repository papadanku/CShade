
#include "cShade.fxh"
#include "cColor.fxh"

#if !defined(INCLUDE_CSHADE_HDR)
    #define INCLUDE_CSHADE_HDR

    uniform int _CShade_InverseTonemapper <
        ui_category_closed = true;
        ui_category = "Pipeline / Input / Pre-Processing";
        ui_label = "Inverse Tonemap";
        ui_tooltip = "Select a tonemap operator for sampling the backbuffer";
        ui_type = "combo";
        ui_items = "None\0Reinhard [Inverse]\0Reinhard Squared [Inverse]\0AMD Resolve [Inverse]\0Logarithmic C [Decode]\0";
    > = 0;

    float4 CShadeHDR_Tex2D_InvTonemap(sampler Source, float2 Tex)
    {
        return CColor_ApplyInverseTonemap(tex2D(Source, Tex), _CShade_InverseTonemapper);
    }

    float4 CShadeHDR_Tex2Dlod_TonemapToRGB(sampler Source, float4 Tex)
    {
        return CColor_ApplyInverseTonemap(tex2Dlod(Source, Tex), _CShade_InverseTonemapper);
    }

#endif