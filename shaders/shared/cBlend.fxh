
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
        #define CBLEND_BLENDENABLE FALSE
    #endif

    #ifndef CBLEND_BLENDOP
        #define CBLEND_BLENDOP ADD
    #endif
    #ifndef CBLEND_BLENDOPALPHA
        #define CBLEND_BLENDOPALPHA ADD
    #endif
    #ifndef CBLEND_SRCBLEND
        #define CBLEND_SRCBLEND ONE
    #endif
    #ifndef CBLEND_SRCBLENDALPHA
        #define CBLEND_SRCBLENDALPHA ONE
    #endif
    #ifndef CBLEND_DESTBLEND
        #define CBLEND_DESTBLEND ZERO
    #endif
    #ifndef CBLEND_DESTBLENDALPHA
        #define CBLEND_DESTBLENDALPHA ZERO
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

    uniform int _CShadeOutputMode <
        ui_category = "[ Pipeline | Output | Blending ]";
        ui_label = "Debug Output";
        ui_tooltip = "Reset this option once you are done debugging.";
        ui_type = "combo";
        ui_items = "No Debug\0Display Alpha\0";
    > = 0;

    uniform float _CShadeAlphaFactor <
        ui_category = "[ Pipeline | Output | Blending ]";
        ui_label = "Alpha Factor";
        ui_tooltip = "Use this to adjust blending factor when using the following Blends: SRCALPHA/INVSRCALPHA";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 1.0;

    float4 CBlend_OutputChannels(float4 Color)
    {
        switch(_CShadeOutputMode)
        {
            case 0:
                return Color;
            case 1:
                return Color.a;
            default:
                return Color;
        }
    }

#endif
