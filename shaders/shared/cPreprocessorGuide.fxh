
#if !defined(INCLUDE_CPREPROCESSOR_GUIDE)
    #define INCLUDE_CPREPROCESSOR_GUIDE

    uniform int _CShadePreprocessorGuide <
        ui_category_closed = true;
        ui_category = "Preprocessor Guide · CBlend";
        ui_label = " ";
        ui_type = "radio";
        ui_text = "\nCBLEND_BLENDENABLE - Enables or disables color and alpha blending for the render target.\n\n\tOptions: TRUE, FALSE\n\tDefault: FALSE\n\n\tNote: To blend with existing data, you must also set ClearRenderTargets to FALSE.\n\nCBLEND_BLENDOP - Defines the operator used for color blending.\n\n\tOptions: ADD, SUBTRACT, REVSUBTRACT, MIN, MAX\n\tDefault: ADD\n\nCBLEND_BLENDOPALPHA - Defines the operator used for alpha blending.\n\n\tOptions: ADD, SUBTRACT, REVSUBTRACT, MIN, MAX\n\tDefault: ADD\n\nCBLEND_SRCBLEND - Specifies the source operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ONE\n\nCBLEND_SRCBLENDALPHA - Specifies the optional pre-blend operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ONE\n\nCBLEND_DESTBLEND - Specifies the destination operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ZERO\n\nCBLEND_DESTBLENDALPHA - Specifies the optional pre-blend operation for blending.\n\n\tOptions: ZERO, ONE, SRCCOLOR, SRCALPHA, INVSRCCOLOR, INVSRCALPHA, DESTCOLOR, DESTALPHA, INVDESTCOLOR, INVDESTALPHA\n\tDefault: ZERO\n\nCBLEND_WRITEMASK - A color mask applied to the output before it is written to the render target.\n\n\tOptions: RED, GREEN, BLUE, ALPHA\n\tDefault: RED + GREEN + BLUE + ALPHA\n\n";
    > = 0;

#endif
