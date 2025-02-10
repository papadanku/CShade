
#include "cShade.fxh"

#if !defined(INCLUDE_CSHADE_HDR)
    #define INCLUDE_CSHADE_HDR

    uniform int _CShadeInputTonemapOperator <
        ui_category = "[ Pipeline | Input | Pre-Processing ]";
        ui_label = "Inverse Tonemap";
        ui_tooltip = "Select a tonemap operator for sampling the backbuffer";
        ui_type = "combo";
        ui_items = "None\0Inverse Reinhard\0Inverse Reinhard Squared\0Inverse Standard\0Inverse Exponential\0Inverse AMD Resolve\0";
    > = 0;

    float4 CShadeHDR_Tex2D_InvTonemap(sampler Source, float2 Tex)
    {
        return CTonemap_ApplyInverseTonemap(tex2D(Source, Tex), _CShadeInputTonemapOperator);
    }

    float4 CShadeHDR_Tex2Dlod_InvTonemap(sampler Source, float4 Tex)
    {
        return CTonemap_ApplyInverseTonemap(tex2Dlod(Source, Tex), _CShadeInputTonemapOperator);
    }

#endif