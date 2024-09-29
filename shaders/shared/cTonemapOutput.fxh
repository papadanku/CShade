
#include "cTonemap.fxh"

#if !defined(INCLUDE_CTONEMAP_OUTPUT)
    #define INCLUDE_CTONEMAP_OUTPUT

    uniform int _CShadeTonemapOperator <
        ui_category = "[ Pipeline | Output | Tonemapping ]";
        ui_label = "Tonemap Operator";
        ui_tooltip = "Select a tonemap operator for the output";
        ui_type = "combo";
        ui_items = "None\0Reinhard\0Reinhard Squared\0Standard\0Exponential\0AMD Resolve\0";
    > = 3;

    float3 CTonemap_ApplyOutputTonemap(float3 HDR)
    {
        return CTonemap_ApplyTonemap(HDR, _CShadeTonemapOperator);
    }

#endif
