
#if !defined(INCLUDE_CMACROS)
    #define INCLUDE_CMACROS

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

#endif
