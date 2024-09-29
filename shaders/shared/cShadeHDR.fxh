
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

    float4 CShade_BackBuffer2D(float2 Tex)
    {
        return CTonemap_ApplyInverseTonemap(tex2D(CShade_SampleColorTex, Tex), _CShadeInputTonemapOperator);
    }

    float4 CShade_BackBuffer2Dlod(float4 Tex)
    {
        return CTonemap_ApplyInverseTonemap(tex2Dlod(CShade_SampleColorTex, Tex), _CShadeInputTonemapOperator);
    }

#endif