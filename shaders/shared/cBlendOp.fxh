
#if !defined(INCLUDE_BLENDOP)
    #define INCLUDE_BLENDOP

    /*
        BlendEnable0 to BlendEnable7 allow to enable or disable color and alpha blending for the respective render target.
        Don't forget to also set "ClearRenderTargets" to "false" if you want to blend with existing data in a render target.
        BlendEnable and BlendEnable0 are aliases,

        The operator used for color and alpha blending.
        To set these individually for each render target, append the render target index to the pass state name, e.g. BlendOp3 for the fourth render target (zero-based index 3).
        Available values:
            ADD, SUBTRACT, REVSUBTRACT, MIN, MAX

        The data source and optional pre-blend operation used for blending.
        To set these individually for each render target, append the render target index to the pass state name, e.g. SrcBlend3 for the fourth render target (zero-based index 3).
        Available values:
            ZERO, ONE,
            SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA
            DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA
    */

    #ifndef CBLENDOP_OUTPUT_BLEND_ENABLE
        #define CBLENDOP_OUTPUT_BLEND_ENABLE FALSE
    #endif
    #ifndef CBLENDOP_OUTPUT_BLEND_OP
        #define CBLENDOP_OUTPUT_BLEND_OP ADD
    #endif
    #ifndef CBLENDOP_OUTPUT_BLEND_OP_ALPHA
        #define CBLENDOP_OUTPUT_BLEND_OP_ALPHA ADD
    #endif
    #ifndef CBLENDOP_OUTPUT_SRC_BLEND
        #define CBLENDOP_OUTPUT_SRC_BLEND ONE
    #endif
    #ifndef CBLENDOP_OUTPUT_SRC_BLEND_ALPHA
        #define CBLENDOP_OUTPUT_SRC_BLEND_ALPHA ONE
    #endif
    #ifndef CBLENDOP_OUTPUT_DEST_BLEND
        #define CBLENDOP_OUTPUT_DEST_BLEND ZERO
    #endif
    #ifndef CBLENDOP_OUTPUT_DEST_BLEND_ALPHA
        #define CBLENDOP_OUTPUT_DEST_BLEND_ALPHA ZERO
    #endif

    #define CBLENDOP_OUTPUT_CREATE_STATES() \
        BlendEnable = CBLENDOP_OUTPUT_BLEND_ENABLE; \
        BlendOp = CBLENDOP_OUTPUT_BLEND_OP; \
        BlendOpAlpha = CBLENDOP_OUTPUT_BLEND_OP_ALPHA; \
        SrcBlend = CBLENDOP_OUTPUT_SRC_BLEND; \
        SrcBlendAlpha = CBLENDOP_OUTPUT_SRC_BLEND_ALPHA; \
        DestBlend = CBLENDOP_OUTPUT_DEST_BLEND; \
        DestBlendAlpha = CBLENDOP_OUTPUT_DEST_BLEND_ALPHA; \

    uniform float _CShadeAlphaFactor <
        ui_category = "Output: Blending";
        ui_label = "Alpha Factor";
        ui_tooltip = "Use this to adjust blending factor when using the following Blends: SRCALPHA/INVSRCALPHA";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 1.0;

#endif