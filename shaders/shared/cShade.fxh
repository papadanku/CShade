
#if !defined(INCLUDE_CSHADE)
    #define INCLUDE_CSHADE

    /*
        [Macros and macro accessories]

        https://graphics.stanford.edu/~seander/bithacks.html
    */

    #define CSHADE_TO_STRING(X) #X
    #define CSHADE_GET_EVEN(X) (X + (X & 1))
    #define CSHADE_GET_MIN(X, Y) (Y ^ ((X ^ Y) & -(X < Y)))
    #define CSHADE_GET_MAX(X, Y) (X ^ ((X ^ Y) & -(X < Y)))

    #define CSHADE_FLT16_SMALLEST_SUBNORMAL float((1.0 / (1 << 14)) * (0.0 + (1.0 / (1 << 10))))

    #define CSHADE_ASPECT_RATIO float(BUFFER_WIDTH * (1.0 / BUFFER_HEIGHT))
    #define CSHADE_BUFFER_SIZE_0 int2(BUFFER_WIDTH, BUFFER_HEIGHT)
    #define CSHADE_BUFFER_SIZE_1 int2(CSHADE_BUFFER_SIZE_0 >> 1)
    #define CSHADE_BUFFER_SIZE_2 int2(CSHADE_BUFFER_SIZE_0 >> 2)
    #define CSHADE_BUFFER_SIZE_3 int2(CSHADE_BUFFER_SIZE_0 >> 3)
    #define CSHADE_BUFFER_SIZE_4 int2(CSHADE_BUFFER_SIZE_0 >> 4)
    #define CSHADE_BUFFER_SIZE_5 int2(CSHADE_BUFFER_SIZE_0 >> 5)
    #define CSHADE_BUFFER_SIZE_6 int2(CSHADE_BUFFER_SIZE_0 >> 6)
    #define CSHADE_BUFFER_SIZE_7 int2(CSHADE_BUFFER_SIZE_0 >> 7)
    #define CSHADE_BUFFER_SIZE_8 int2(CSHADE_BUFFER_SIZE_0 >> 8)

    #ifndef CSHADE_SRGB_RENDERING
        #define CSHADE_SRGB_RENDERING 1
    #endif

    #if CSHADE_SRGB_RENDERING && (BUFFER_COLOR_BIT_DEPTH == 8)
        #define CSHADE_READ_SRGB TRUE
        #define CSHADE_WRITE_SRGB TRUE
    #else
        #define CSHADE_READ_SRGB FALSE
        #define CSHADE_WRITE_SRGB FALSE
    #endif

    #define CSHADE_CREATE_OPTION(DATATYPE, NAME, CATEGORY, LABEL, TYPE, MAXIMUM, DEFAULT) \
        uniform DATATYPE NAME < \
            ui_category = CATEGORY; \
            ui_label = LABEL; \
            ui_type = TYPE; \
            ui_min = 0.0; \
            ui_max = MAXIMUM; \
        > = DEFAULT;

    #define CSHADE_CREATE_TEXTURE(TEXTURE_NAME, SIZE, FORMAT, LEVELS) \
        texture2D TEXTURE_NAME < pooled = false; > \
        { \
            Width = SIZE.x; \
            Height = SIZE.y; \
            Format = FORMAT; \
            MipLevels = LEVELS; \
        };

    #define CSHADE_CREATE_TEXTURE_POOLED(TEXTURE_NAME, SIZE, FORMAT, LEVELS) \
        texture2D TEXTURE_NAME < pooled = true; > \
        { \
            Width = SIZE.x; \
            Height = SIZE.y; \
            Format = FORMAT; \
            MipLevels = LEVELS; \
        };

    #define CSHADE_CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, MAGFILTER, MINFILTER, MIPFILTER, ADDRESSU, ADDRESSV, ADDRESSW) \
        sampler2D SAMPLER_NAME \
        { \
            Texture = TEXTURE; \
            MagFilter = MAGFILTER; \
            MinFilter = MINFILTER; \
            MipFilter = MIPFILTER; \
            AddressU = ADDRESSU; \
            AddressV = ADDRESSV; \
            AddressW = ADDRESSW; \
        };

    #define CSHADE_CREATE_SAMPLER_LODBIAS(SAMPLER_NAME, TEXTURE, MAGFILTER, MINFILTER, MIPFILTER, ADDRESSU, ADDRESSV, ADDRESSW, BIAS) \
        sampler2D SAMPLER_NAME \
        { \
            Texture = TEXTURE; \
            MagFilter = MAGFILTER; \
            MinFilter = MINFILTER; \
            MipFilter = MIPFILTER; \
            AddressU = ADDRESSU; \
            AddressV = ADDRESSV; \
            AddressW = ADDRESSW; \
            MipLODBias = BIAS; \
        };

    #define CSHADE_CREATE_SRGB_SAMPLER(SAMPLER_NAME, TEXTURE, MAGFILTER, MINFILTER, MIPFILTER, ADDRESSU, ADDRESSV, ADDRESSW) \
        sampler2D SAMPLER_NAME \
        { \
            Texture = TEXTURE; \
            MagFilter = MAGFILTER; \
            MinFilter = MINFILTER; \
            MipFilter = MIPFILTER; \
            AddressU = ADDRESSU; \
            AddressV = ADDRESSV; \
            AddressW = ADDRESSW; \
            SRGBTexture = CSHADE_READ_SRGB; \
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

#endif
