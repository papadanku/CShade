
#include "cTonemap.fxh"

#if !defined(INCLUDE_CSHADE)
    #define INCLUDE_CSHADE

    /*
        [Macros and macro accessories]
        ---
        https://graphics.stanford.edu/~seander/bithacks.html
    */

    #define GET_EVEN(X) (X + (X & 1))
    #define GET_MIN(X, Y) (Y ^ ((X ^ Y) & -(X < Y)))
    #define GET_MAX(X, Y) (X ^ ((X ^ Y) & -(X < Y)))

    #define FP16_SMALLEST_SUBNORMAL float((1.0 / (1 << 14)) * (0.0 + (1.0 / (1 << 10))))

    #define ASPECT_RATIO float(BUFFER_WIDTH * (1.0 / BUFFER_HEIGHT))
    #define BUFFER_SIZE_0 int2(BUFFER_WIDTH, BUFFER_HEIGHT)
    #define BUFFER_SIZE_1 int2(BUFFER_SIZE_0 >> 1)
    #define BUFFER_SIZE_2 int2(BUFFER_SIZE_0 >> 2)
    #define BUFFER_SIZE_3 int2(BUFFER_SIZE_0 >> 3)
    #define BUFFER_SIZE_4 int2(BUFFER_SIZE_0 >> 4)
    #define BUFFER_SIZE_5 int2(BUFFER_SIZE_0 >> 5)
    #define BUFFER_SIZE_6 int2(BUFFER_SIZE_0 >> 6)
    #define BUFFER_SIZE_7 int2(BUFFER_SIZE_0 >> 7)
    #define BUFFER_SIZE_8 int2(BUFFER_SIZE_0 >> 8)

    #if BUFFER_COLOR_BIT_DEPTH == 8
        #define READ_SRGB TRUE
        #define WRITE_SRGB TRUE
    #else
        #define READ_SRGB FALSE
        #define WRITE_SRGB FALSE
    #endif

    #define CREATE_OPTION(DATATYPE, NAME, CATEGORY, LABEL, TYPE, MAXIMUM, DEFAULT) \
        uniform DATATYPE NAME < \
            ui_category = CATEGORY; \
            ui_label = LABEL; \
            ui_type = TYPE; \
            ui_min = 0.0; \
            ui_max = MAXIMUM; \
        > = DEFAULT;

    #define CREATE_TEXTURE(TEXTURE_NAME, SIZE, FORMAT, LEVELS) \
        texture2D TEXTURE_NAME < pooled = false; > \
        { \
            Width = SIZE.x; \
            Height = SIZE.y; \
            Format = FORMAT; \
            MipLevels = LEVELS; \
        };

    #define CREATE_TEXTURE_POOLED(TEXTURE_NAME, SIZE, FORMAT, LEVELS) \
        texture2D TEXTURE_NAME < pooled = true; > \
        { \
            Width = SIZE.x; \
            Height = SIZE.y; \
            Format = FORMAT; \
            MipLevels = LEVELS; \
        };

    #define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, ADDRESSU, ADDRESSV, ADDRESSW) \
        sampler2D SAMPLER_NAME \
        { \
            Texture = TEXTURE; \
            MagFilter = FILTER; \
            MinFilter = FILTER; \
            MipFilter = FILTER; \
            AddressU = ADDRESSU; \
            AddressV = ADDRESSV; \
            AddressW = ADDRESSW; \
        };

    #define CREATE_SRGB_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, ADDRESSU, ADDRESSV, ADDRESSW) \
        sampler2D SAMPLER_NAME \
        { \
            Texture = TEXTURE; \
            MagFilter = FILTER; \
            MinFilter = FILTER; \
            MipFilter = FILTER; \
            AddressU = ADDRESSU; \
            AddressV = ADDRESSV; \
            AddressW = ADDRESSW; \
            SRGBTexture = READ_SRGB; \
        };

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
