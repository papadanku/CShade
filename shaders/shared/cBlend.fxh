
/*
    This header file defines macros, blend states, and functions for managing color and alpha blending operations within ReShade shaders. It provides a standardized way to configure render target blending, including blend enable/disable, blend operators, source and destination blend factors, and render target write masks. Additionally, it includes functionality for channel swizzling and debug output of individual color channels.
*/

#if !defined(CSHADE_BLENDING)
    #define CSHADE_BLENDING

    #ifndef CSHADE_APPLY_BLENDING
        #define CSHADE_APPLY_BLENDING 1
    #endif

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
    
    #ifndef CBLEND_APPLY_PRESET
        #define CBLEND_APPLY_PRESET 0
    #endif

    #if (CBLEND_APPLY_PRESET == 1)
        #define CBLEND_BLENDENABLE_VALUE TRUE
        #define CBLEND_BLENDOP_VALUE ADD
        #define CBLEND_BLENDOPALPHA_VALUE ADD
        #define CBLEND_SRCBLEND_VALUE SRCALPHA
        #define CBLEND_SRCBLENDALPHA_VALUE ONE
        #define CBLEND_DESTBLEND_VALUE INVSRCALPHA
        #define CBLEND_DESTBLENDALPHA_VALUE ZERO
    #else
        #define CBLEND_BLENDENABLE_VALUE FALSE
        #define CBLEND_BLENDOP_VALUE ADD
        #define CBLEND_BLENDOPALPHA_VALUE ADD
        #define CBLEND_SRCBLEND_VALUE ONE
        #define CBLEND_SRCBLENDALPHA_VALUE ONE
        #define CBLEND_DESTBLEND_VALUE ZERO
        #define CBLEND_DESTBLENDALPHA_VALUE ZERO
    #endif

    /*
        Bits positions used for CBLEND_RENDERTARGETWRITEMASK, simplified for users
    */
    #define RED 1
    #define GREEN 2
    #define BLUE 4
    #define ALPHA 8
    #define ON 1
    #define OFF 0

    #ifndef CBLEND_BLENDENABLE
        #define CBLEND_BLENDENABLE CBLEND_BLENDENABLE_VALUE
    #endif
    #ifndef CBLEND_BLENDOP
        #define CBLEND_BLENDOP CBLEND_BLENDOP_VALUE
    #endif
    #ifndef CBLEND_BLENDOPALPHA
        #define CBLEND_BLENDOPALPHA CBLEND_BLENDOPALPHA_VALUE
    #endif
    #ifndef CBLEND_SRCBLEND
        #define CBLEND_SRCBLEND CBLEND_SRCBLEND_VALUE
    #endif
    #ifndef CBLEND_SRCBLENDALPHA
        #define CBLEND_SRCBLENDALPHA CBLEND_SRCBLENDALPHA_VALUE
    #endif
    #ifndef CBLEND_DESTBLEND
        #define CBLEND_DESTBLEND CBLEND_DESTBLEND_VALUE
    #endif
    #ifndef CBLEND_DESTBLENDALPHA
        #define CBLEND_DESTBLENDALPHA CBLEND_DESTBLENDALPHA_VALUE
    #endif
    #ifndef CBLEND_WRITEMASK
        #define CBLEND_WRITEMASK RED + GREEN + BLUE + ALPHA
    #endif

    #define CBLEND_CREATE_STATES() \
        BlendEnable = CBLEND_BLENDENABLE; \
        BlendOp = CBLEND_BLENDOP; \
        BlendOpAlpha = CBLEND_BLENDOPALPHA; \
        SrcBlend = CBLEND_SRCBLEND; \
        SrcBlendAlpha = CBLEND_SRCBLENDALPHA; \
        DestBlend = CBLEND_DESTBLEND; \
        DestBlendAlpha = CBLEND_DESTBLENDALPHA; \
        RenderTargetWriteMask = int(CBLEND_WRITEMASK);

    #if CSHADE_APPLY_BLENDING
        uniform float _CShade_AlphaFactor <
            ui_category_closed = true;
            ui_category = "Output / Blending";
            ui_text = "ALPHA BLEND";
            ui_label = "Alpha Blend Weight";
            ui_tooltip = "Adjusts the blending weight when using source alpha (SRCALPHA) or inverse source alpha (INVSRCALPHA) blend modes.";
            ui_type = "slider";
            ui_min = 0.0;
            ui_max = 1.0;
        > = 1.0;

        uniform int _CBlendPreprocessorGuide <
            ui_category_closed = true;
            ui_category = "Preprocessor Guide / Blending";
            ui_label = " ";
            ui_type = "radio";
            ui_text = "\nCBLEND_BLENDENABLE - Enables or disables color and alpha blending for the render target.\n\n\tOptions: TRUE, FALSE\n\tDefault: FALSE\n\n\tNote: To blend with existing data, you must also set ClearRenderTargets to FALSE.\n\nCBLEND_BLENDOP - Defines the operator used for color blending.\n\n\tOptions: ADD, SUBTRACT, REVSUBTRACT, MIN, MAX\n\tDefault: ADD\n\nCBLEND_BLENDOPALPHA - Defines the operator used for alpha blending.\n\n\tOptions: ADD, SUBTRACT, REVSUBTRACT, MIN, MAX\n\tDefault: ADD\n\nCBLEND_SRCBLEND - Specifies the source operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ONE\n\nCBLEND_SRCBLENDALPHA - Specifies the optional pre-blend operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ONE\n\nCBLEND_DESTBLEND - Specifies the destination operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ZERO\n\nCBLEND_DESTBLENDALPHA - Specifies the optional pre-blend operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ZERO\n\nCBLEND_WRITEMASK - A color mask applied to the output before it is written to the render target.\n\n\tOptions: RED, GREEN, BLUE, ALPHA\n\tDefault: RED + GREEN + BLUE + ALPHA\n\n";
        > = 0;

        uniform int _CBlendPreprocessorGuidePreset <
            ui_category_closed = true;
            ui_category = "Preprocessor Guide / Blending / Presets";
            ui_label = " ";
            ui_type = "radio";
            ui_text = "\nCBLEND_APPLY_PRESET 0 (Default):\n\n\tCBLEND_BLENDENABLE_VALUE FALSE\n\tCBLEND_BLENDOP_VALUE ADD\n\tCBLEND_BLENDOPALPHA_VALUE ADD\n\tCBLEND_SRCBLEND_VALUE ONE\n\tCBLEND_SRCBLENDALPHA_VALUE ONE\n\tCBLEND_DESTBLEND_VALUE ZERO\n\tCBLEND_DESTBLENDALPHA_VALUE ZERO\n\nCBLEND_APPLY_PRESET 1 (Enables Alpha Blending):\n\n\tCBLEND_BLENDENABLE_VALUE TRUE\n\tCBLEND_BLENDOP_VALUE ADD\n\tCBLEND_BLENDOPALPHA_VALUE ADD\n\tCBLEND_SRCBLEND_VALUE SRCALPHA\n\tCBLEND_SRCBLENDALPHA_VALUE ONE\n\tCBLEND_DESTBLEND_VALUE INVSRCALPHA\n\tCBLEND_DESTBLENDALPHA_VALUE ZERO\n\n";
        > = 0;
    #endif
#endif
