#define CSHADE_MEDIAN

#include "shared/cBlur.fxh"
#include "shared/cMath.fxh"


#ifndef HIERARCHIAL_LEVELS
    #define HIERARCHIAL_LEVELS 5
#endif

#include "shared/cShadeHDR.fxh"

/*
    [Pixel Shaders]
*/

#define CREATE_MEDIAN_PS(METHOD_NAME, SCALE) \
    float4 METHOD_NAME(CShade_VS2PS_Quad Input) : SV_TARGET0 \
    { \
        return CBlur_GetMedian(CShade_SampleColorTex, Input.Tex0, SCALE); \
    } \

CREATE_MEDIAN_PS(PS_Median5, 4.0)
CREATE_MEDIAN_PS(PS_Median4, 3.0)
CREATE_MEDIAN_PS(PS_Median3, 2.0)
CREATE_MEDIAN_PS(PS_Median2, 1.0)
CREATE_MEDIAN_PS(PS_Median1, 0.0)

#define CREATE_MEDIAN_PASS(PIXELSHADER) \
    pass \
    { \
        SRGBWriteEnable = WRITE_SRGB; \
        VertexShader = CShade_VS_Quad; \
        PixelShader = PIXELSHADER; \
    } \

technique CShade_Median < ui_tooltip = "Iterative median filter"; >
{
    #if HIERARCHIAL_LEVELS > 4
        CREATE_MEDIAN_PASS(PS_Median5)
    #endif
    #if HIERARCHIAL_LEVELS > 3
        CREATE_MEDIAN_PASS(PS_Median4)
    #endif
    #if HIERARCHIAL_LEVELS > 2
        CREATE_MEDIAN_PASS(PS_Median3)
    #endif
    #if HIERARCHIAL_LEVELS > 1
        CREATE_MEDIAN_PASS(PS_Median2)
    #endif
    CREATE_MEDIAN_PASS(PS_Median1)
}
