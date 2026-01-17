
/*
    This header file serves as a core utility and macro definition library for the CShade project. It provides fundamental macros for handling preprocessor directives, bitwise operations, and defining common buffer sizes. Crucially, it defines macros for creating and managing textures and samplers with various filtering and addressing modes, including specific handling for sRGB. It also includes global texture declarations for the backbuffer (CShade_ColorTex) and corresponding samplers, along with a standard vertex shader (CShade_VS_Quad) for full-screen quad rendering. This file ensures consistency and simplifies common tasks across CShade shaders.
*/

#include "cMacros.fxh"

#if !defined(INCLUDE_CSHADE)
    #define INCLUDE_CSHADE

    /* Buffer System */

    texture2D CShade_ColorTex : COLOR;

    sampler2D CShade_SampleColorTex
    {
        Texture = CShade_ColorTex;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        SRGBTexture = CSHADE_READ_SRGB;
    };

    sampler2D CShade_SampleGammaTex
    {
        Texture = CShade_ColorTex;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        SRGBTexture = FALSE;
    };

    /* Simple Vertex Shader */

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

    /* CShade's Composite System */

    #include "cCamera.fxh"
    #include "cComposite.fxh"
    #include "cLens.fxh"
    #include "cBlend.fxh"

    void CShade_Render(inout float4 Output, in float2 HPos, in float2 Tex)
    {
        // Apply (optional) color grading
        #if defined(CSHADE_COMPOSITE)
            CComposite_ApplyOutput(Output.rgb);
        #endif

        // Apply (optional) lens
        #if CSHADE_APPLY_VIGNETTE
            float2 UNormTex = Tex - 0.5;
            CLens_ApplyVignette(Output.rgb, UNormTex, 0.0, _CLens_Vignette);
        #endif

        // Apply (optional) vignette
        #if CSHADE_APPLY_GRAIN
            CLens_ApplyFilmGrain(Output.rgb, HPos, _CLens_GrainScale, _CLens_GrainAmount, _CLens_GrainSeed);
        #endif

        // Apply (optional) exposure-peaking
        #if defined(CSHADE_APPLY_PEAKING)
            CComposite_ApplyExposurePeaking(Output.rgb, HPos);
        #endif

        #if defined(CSHADE_BLENDING)
            Output = CComposite_OutputChannels(Output.rgb, Output.a);
        #endif
    }

#endif
