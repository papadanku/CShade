
#include "cMacros.fxh"

#if !defined(INCLUDE_GRAPHICS)
    #define INCLUDE_GRAPHICS

    /*
        [Buffer]
    */

    texture2D CShade_ColorTex : COLOR;

    sampler2D CShade_SampleColorTex
    {
        Texture = CShade_ColorTex;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        SRGBTexture = READ_SRGB;
    };

    sampler2D CShade_SampleGammaTex
    {
        Texture = CShade_ColorTex;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        SRGBTexture = FALSE;
    };

    /*
        [Simple Vertex Shader]
    */

    struct CShade_APP2VS
    {
        uint ID : SV_VERTEXID;
    };

    struct CShade_VS2PS_Quad
    {
        float4 HPos : SV_POSITION;
        float2 Tex0 : TEXCOORD0;
    };

    CShade_VS2PS_Quad CShade_VS_Quad(CShade_APP2VS Input)
    {
        CShade_VS2PS_Quad Output;
        Output.Tex0.x = (Input.ID == 2) ? 2.0 : 0.0;
        Output.Tex0.y = (Input.ID == 1) ? 2.0 : 0.0;
        Output.HPos = float4(Output.Tex0 * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
        return Output;
    }

    /*
        [Math Functions]
    */

    int2 CShade_GetScreenSizeFromTex(float2 Tex)
    {
        return max(round(1.0 / fwidth(Tex)), 1.0);
    }

    float2 CShade_GetPixelSizeFromTex(float2 Tex)
    {
        return 1.0 / CShade_GetScreenSizeFromTex(Tex);
    }

#endif
