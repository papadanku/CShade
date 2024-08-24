
#include "cMacros.fxh"

#if !defined(INCLUDE_GRAPHICS)
    #define INCLUDE_GRAPHICS

    uniform float2 _CShadeTransformScale <
        ui_category = "[ Pipeline | Input | Texture Coordinates ]";
        ui_label = "Scale";
        ui_type = "drag";
    > = 1.0;

    uniform float _CShadeTransformRotation <
        ui_category = "[ Pipeline | Input | Texture Coordinates ]";
        ui_label = "Rotation";
        ui_type = "drag";
    > = 0.0;

    uniform float2 _CShadeTransformTranslate <
        ui_category = "[ Pipeline | Input | Texture Coordinates ]";
        ui_label = "Translation";
        ui_type = "drag";
    > = 0.0;

    #ifndef CSHADE_BACKBUFFER_ADDRESSU
        #define CSHADE_BACKBUFFER_ADDRESSU CLAMP
    #endif
    #ifndef CSHADE_BACKBUFFER_ADDRESSV
        #define CSHADE_BACKBUFFER_ADDRESSV CLAMP
    #endif

    #ifndef CSHADE_BACKBUFFER_ADDRESSW
        #define CSHADE_BACKBUFFER_ADDRESSW CLAMP
    #endif

    float2 CShade_PerturbTex(float2 Tex)
    {
        float RotationAngle = radians(_CShadeTransformRotation) * 360.0;

        float2x2 RotationMatrix = float2x2
        (
            // Row 1
            cos(RotationAngle), -sin(RotationAngle),
            // Row 2
            sin(RotationAngle), cos(RotationAngle)
        );

        float3x3 TranslationMatrix = float3x3
        (
            // Row 1
            1.0, 0.0, 0.0,
            // Row 2
            0.0, 1.0, 0.0,
            // Row 3
            _CShadeTransformTranslate.x, _CShadeTransformTranslate.y, 1.0
        );

        float2x2 ScalingMatrix = float2x2
        (
            // Row 1
            _CShadeTransformScale.x, 0.0,
            // Row 2
            0.0, _CShadeTransformScale.y
        );

        // Scale TexCoord from [0,1] to [-1,1]
        Tex = (Tex * 2.0) - 1.0;

        // Do transformations here
        Tex = mul(Tex, RotationMatrix);
        Tex = mul(float3(Tex, 1.0), TranslationMatrix).xy;
        Tex = mul(Tex, ScalingMatrix);

        // Scale TexCoord from [-1,1] to [0,1]
        Tex = Tex * 0.5 + 0.5;

        return Tex;
    }

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
        AddressU = CSHADE_BACKBUFFER_ADDRESSU;
        AddressV = CSHADE_BACKBUFFER_ADDRESSV;
        AddressW = CSHADE_BACKBUFFER_ADDRESSW;
        SRGBTexture = READ_SRGB;
    };

    sampler2D CShade_SampleGammaTex
    {
        Texture = CShade_ColorTex;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CSHADE_BACKBUFFER_ADDRESSU;
        AddressV = CSHADE_BACKBUFFER_ADDRESSV;
        AddressW = CSHADE_BACKBUFFER_ADDRESSW;
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
        Output.Tex0.xy = CShade_PerturbTex(Output.Tex0.xy);
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
