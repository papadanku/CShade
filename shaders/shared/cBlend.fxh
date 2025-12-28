
/*
    This header file defines macros, blend states, and functions for managing color and alpha blending operations within ReShade shaders. It provides a standardized way to configure render target blending, including blend enable/disable, blend operators, source and destination blend factors, and render target write masks. Additionally, it includes functionality for channel swizzling and debug output of individual color channels.
*/

#if !defined(INCLUDE_CBLENDOP)
    #define INCLUDE_CBLENDOP

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

    uniform float _CShade_AlphaFactor <
        ui_category_closed = true;
        ui_category = "Pipeline / Output / Merge";
        ui_text = "Alpha Blend";
        ui_label = "Alpha Blend Weight";
        ui_tooltip = "Adjusts the blending weight when using source alpha (SRCALPHA) or inverse source alpha (INVSRCALPHA) blend modes.";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 1.0;

    uniform int _CShade_SwizzleRed <
        ui_category_closed = true;
        ui_category = "Pipeline / Output / Merge";
        ui_text = "\nColor Write Mask";
        ui_label = "Map Red Channel To";
        ui_type = "combo";
        ui_items = "Red\0Green\0Blue\0Alpha\0None\0";
        ui_tooltip = "Maps the red output channel to one of the source color or alpha channels, or disables it.";
    > = 0;

    uniform int _CShade_SwizzleGreen <
        ui_category = "Pipeline / Output / Merge";
        ui_label = "Map Green Channel To";
        ui_type = "combo";
        ui_items = "Red\0Green\0Blue\0Alpha\0None\0";
        ui_tooltip = "Maps the green output channel to one of the source color or alpha channels, or disables it.";
    > = 1;

    uniform int _CShade_SwizzleBlue <
        ui_category = "Pipeline / Output / Merge";
        ui_label = "Map Blue Channel To";
        ui_type = "combo";
        ui_items = "Red\0Green\0Blue\0Alpha\0None\0";
        ui_tooltip = "Maps the blue output channel to one of the source color or alpha channels, or disables it.";
    > = 2;

    uniform int _CShade_SwizzleAlpha <
        ui_category = "Pipeline / Output / Merge";
        ui_label = "Map Alpha Channel To";
        ui_type = "combo";
        ui_items = "Red\0Green\0Blue\0Alpha\0None\0";
        ui_tooltip = "Maps the alpha output channel to one of the source color or alpha channels, or disables it.";
    > = 3;

    uniform int _CShade_OutputMode <
        ui_category = "Pipeline / Output / Merge";
        ui_label = " ";
        ui_text = "\n[Debug] Show Channel";
        ui_tooltip = "Displays a specific color channel (Red, Green, Blue, or Alpha) for debugging purposes. Remember to reset this option when done.";
        ui_type = "combo";
        ui_items = "All\0Red\0Green\0Blue\0Alpha\0";
    > = 0;

    void CBlend_SwapChannel(inout float Color, in float4 Cache, in int Parameter)
    {
        switch (Parameter)
        {
            case 0:
                Color = Cache.r;
                break;
            case 1:
                Color = Cache.g;
                break;
            case 2:
                Color = Cache.b;
                break;
            case 3:
                Color = Cache.a;
                break;
            default:
                Color = 0.0;
                break;
        }
    }

    float4 CBlend_OutputChannels(float3 Color, float Alpha)
    {
        // Swizzling
        float4 Cache = float4(Color, Alpha);
        float4 Channels = Cache;
        CBlend_SwapChannel(Channels.r, Cache, _CShade_SwizzleRed);
        CBlend_SwapChannel(Channels.g, Cache, _CShade_SwizzleGreen);
        CBlend_SwapChannel(Channels.b, Cache, _CShade_SwizzleBlue);
        CBlend_SwapChannel(Channels.a, Cache, _CShade_SwizzleAlpha);

        // Process OutputColor
        float4 OutputColor = 0.0;
        switch (_CShade_OutputMode)
        {
            case 1:
                OutputColor.r = Channels.r;
                OutputColor.a = 1.0;
                break;
            case 2:
                OutputColor.g = Channels.g;
                OutputColor.a = 1.0;
                break;
            case 3:
                OutputColor.b = Channels.b;
                OutputColor.a = 1.0;
                break;
            case 4: // Write to all channels for alpha, so people can see it
                OutputColor.rgb = Channels.a;
                OutputColor.a = 1.0;
                break;
            default: // No Debug
                OutputColor = Channels;
                break;
        }

        return OutputColor;
    }

    uniform int _CBlendPreprocessorGuide <
        ui_category_closed = true;
        ui_category = "CShade / Preprocessor Guide / Blending";
        ui_label = " ";
        ui_type = "radio";
        ui_text = "\nCBLEND_BLENDENABLE - Enables or disables color and alpha blending for the render target.\n\n\tOptions: TRUE, FALSE\n\tDefault: FALSE\n\n\tNote: To blend with existing data, you must also set ClearRenderTargets to FALSE.\n\nCBLEND_BLENDOP - Defines the operator used for color blending.\n\n\tOptions: ADD, SUBTRACT, REVSUBTRACT, MIN, MAX\n\tDefault: ADD\n\nCBLEND_BLENDOPALPHA - Defines the operator used for alpha blending.\n\n\tOptions: ADD, SUBTRACT, REVSUBTRACT, MIN, MAX\n\tDefault: ADD\n\nCBLEND_SRCBLEND - Specifies the source operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ONE\n\nCBLEND_SRCBLENDALPHA - Specifies the optional pre-blend operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ONE\n\nCBLEND_DESTBLEND - Specifies the destination operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ZERO\n\nCBLEND_DESTBLENDALPHA - Specifies the optional pre-blend operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ZERO\n\nCBLEND_WRITEMASK - A color mask applied to the output before it is written to the render target.\n\n\tOptions: RED, GREEN, BLUE, ALPHA\n\tDefault: RED + GREEN + BLUE + ALPHA\n\n";
    > = 0;

    uniform int _CBlendPreprocessorGuidePreset <
        ui_category_closed = true;
        ui_category = "CShade / Preprocessor Guide / Blending / Presets";
        ui_label = " ";
        ui_type = "radio";
        ui_text = "\nCBLEND_APPLY_PRESET 0 (Default):\n\n\tCBLEND_BLENDENABLE_VALUE FALSE\n\tCBLEND_BLENDOP_VALUE ADD\n\tCBLEND_BLENDOPALPHA_VALUE ADD\n\tCBLEND_SRCBLEND_VALUE ONE\n\tCBLEND_SRCBLENDALPHA_VALUE ONE\n\tCBLEND_DESTBLEND_VALUE ZERO\n\tCBLEND_DESTBLENDALPHA_VALUE ZERO\n\nCBLEND_APPLY_PRESET 1 (Enables Alpha Blending):\n\n\tCBLEND_BLENDENABLE_VALUE TRUE\n\tCBLEND_BLENDOP_VALUE ADD\n\tCBLEND_BLENDOPALPHA_VALUE ADD\n\tCBLEND_SRCBLEND_VALUE SRCALPHA\n\tCBLEND_SRCBLENDALPHA_VALUE ONE\n\tCBLEND_DESTBLEND_VALUE INVSRCALPHA\n\tCBLEND_DESTBLENDALPHA_VALUE ZERO\n\n";
    > = 0;

#endif
