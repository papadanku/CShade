
/*
    This header file provides functions and UI controls for camera-related post-processing effects, primarily focusing on auto-exposure and exposure peaking.

    It allows shaders to dynamically adjust scene brightness, implement different metering methods (average or spot metering), and visualize luminance levels and spot metering areas.

    Abstracted Preprocessor Definitions: CCAMERA_TOGGLE_AUTO_EXPOSURE
*/

#include "cMath.fxh"

#if !defined(INCLUDE_CCAMERA_OUTPUT)
    #define INCLUDE_CCAMERA_OUTPUT

    #if CCAMERA_TOGGLE_AUTO_EXPOSURE
        uniform float _CCamera_ExposureSmoothingSpeed <
            ui_category_closed = true;
            ui_category = "Output / Auto Exposure";
            ui_text = "AUTO EXPOSURE SETTINGS";
            ui_label = "Smoothing Speed";
            ui_type = "slider";
            ui_min = 0.1;
            ui_max = 1.0;
            ui_tooltip = "Controls how quickly the auto-exposure adapts to changes in scene luminance.";
        > = 0.25;

        uniform float _CCamera_ExposureBias <
            ui_category = "Output / Auto Exposure";
            ui_label = "Compensation Bias";
            ui_type = "slider";
            ui_step = 0.001;
            ui_min = -4.0;
            ui_max = 4.0;
            ui_tooltip = "Applies a manual compensation bias to the auto-exposure, adjusting the overall brightness.";
        > = 1.0;

        uniform float _CCamera_ExposureRange <
            ui_category = "Output / Auto Exposure";
            ui_label = "Compensation Range";
            ui_type = "slider";
            ui_step = 0.001;
            ui_min = 1.0;
            ui_max = 4.0;
            ui_tooltip = "Defines the maximum range (in f-stops) that the auto-exposure can adjust the scene brightness.";
        > = 1.0;

        uniform int _CCamera_MeteringType <
            ui_category_closed = true;
            ui_category = "Output / Auto Exposure";
            ui_label = "Adaptation Method";
            ui_type = "combo";
            ui_items = "Average Metering\0Spot Metering\0";
            ui_tooltip = "Selects the method for auto-exposure adaptation: either average metering across the whole scene or spot metering on a specific area.";
        > = 0;

        uniform bool _CCamera_LumaMeter <
            ui_text = "TOOLS - LUMINANCE METERING ";
            ui_category = "Output / Auto Exposure";
            ui_label = "Show Luminance Meter Overlay";
            ui_type = "radio";
            ui_tooltip = "When enabled, displays an overlay that visualizes the scene's luminance levels.";
        > = false;

        uniform float _CCamera_LumaMeterScale <
            ui_category = "Output / Auto Exposure";
            ui_label = "Scale";
            ui_type = "slider";
            ui_min = 1e-3;
            ui_max = 1.0;
            ui_tooltip = "Controls the size or scale of the luminance meter overlay.";
        > = 0.75;

        uniform float2 _CCamera_LumaMeterOffset <
            ui_category = "Output / Auto Exposure";
            ui_label = "Offset";
            ui_type = "slider";
            ui_min = -1.0;
            ui_max = 1.0;
            ui_tooltip = "Adjusts the horizontal and vertical position of the luminance meter overlay.";
        > = float2(0.0, -0.25);

        uniform bool _CCamera_ShowSpotMeterOverlay <
            ui_text = "TOOLS - SPOT METERING";
            ui_category = "Output / Auto Exposure";
            ui_label = "Show Spot Meter Area Overlay";
            ui_type = "radio";
            ui_tooltip = "When enabled, displays an overlay indicating the area used for spot metering.";
        > = false;

        uniform float _CCamera_SpotMeterScale <
            ui_category = "Output / Auto Exposure";
            ui_label = "Scale";
            ui_type = "slider";
            ui_min = 1e-3;
            ui_max = 1.0;
            ui_tooltip = "Controls the size or scale of the spot metering area.";
        > = 0.5;

        uniform float2 _CCamera_SpotMeterOffset <
            ui_category = "Output / Auto Exposure";
            ui_label = "Position Offset";
            ui_type = "slider";
            ui_min = -1.0;
            ui_max = 1.0;
            ui_tooltip = "Adjusts the horizontal and vertical position of the spot metering area.";
        > = 0.0;
    #endif

    uniform float _CCamera_Frametime < source = "frametime"; >;

    struct CCamera_Exposure
    {
        float ExpLuma;
        float Ev100;
        float Value;
    };

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html
    float CCamera_GetLogLuminance(float3 Color)
    {
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            float Luminance = max(max(Color.r, Color.g), Color.b);
            return log(max(Luminance, 1e-2));
        #else
            return Color;
        #endif
    }

    float4 CCamera_CreateExposureTex(float Luminance)
    {
        // .rgb = Output the highest brightness out of red/green/blue component
        // .a = Output the weight for Temporal Smoothing
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            float Delay = 1e-3 * _CCamera_Frametime;
            return float4((float3)Luminance, saturate(Delay * _CCamera_ExposureSmoothingSpeed));
        #else
            return (float4)Luminance;
        #endif
    }

    CCamera_Exposure CCamera_GetExposureData(float LumaTex)
    {
        CCamera_Exposure Output;
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            Output.ExpLuma = exp(LumaTex);
            Output.Ev100 = log2(Output.ExpLuma * 100.0 / 12.5);
            Output.Ev100 -= _CCamera_ExposureBias; // optional manual bias
            Output.Ev100 = clamp(Output.Ev100, -_CCamera_ExposureRange, _CCamera_ExposureRange);
            Output.Value = 1.0 / (1.2 * exp2(Output.Ev100));
            return Output;
        #else
            return Output;
        #endif
    }

    float3 CCamera_ApplyAutoExposure(float3 Color, CCamera_Exposure Input)
    {
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            return Color * Input.Value;
        #else
            return Color;
        #endif
    }

    void CCamera_ApplyAverageLumaOverlay(inout float3 Color, in float2 UnormTex, in CCamera_Exposure E)
    {
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            if (_CCamera_LumaMeter)
            {
                // Maps texture coordinates less-than/equal to the brightness.
                // We use [-1,-1] texture coordinates and bias them by 0.5 to have 0.0 be at the middle-left of the screen.
                UnormTex /= _CCamera_LumaMeterScale;
                UnormTex += float2(-_CCamera_LumaMeterOffset.x, _CCamera_LumaMeterOffset.y);

                float AETex = UnormTex.x + 0.5;
                float3 AEMask = lerp(Color * 0.1, 1.0, AETex <= E.ExpLuma);

                // Mask between auto exposure bar color
                float2 CropTex = UnormTex + float2(0.0, -0.5);
                float2 Crop = step(abs(CropTex), float2(0.5, 0.01));
                float CropMask = Crop.x * Crop.y;

                // Composite
                Color = lerp(Color, AEMask, CropMask);
            }
        #endif
    }

    // Exposure-specific functions
    float2 CCamera_GetSpotMeterTex(float2 Tex)
    {
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            // For spot-metering, we fill the target square texture with the region only
            float2 SpotMeterTex = CMath_UNORMtoSNORM_FLT2(Tex);

            // Expand the UV so [-1, 1] fills the shape of its input texture instead of output
            #if BUFFER_WIDTH > BUFFER_HEIGHT
                SpotMeterTex.x /= CSHADE_ASPECT_RATIO;
            #else
                SpotMeterTex.y /= CSHADE_ASPECT_RATIO;
            #endif

            SpotMeterTex *= _CCamera_SpotMeterScale;
            SpotMeterTex += float2(_CCamera_SpotMeterOffset.x, -_CCamera_SpotMeterOffset.y);
            SpotMeterTex = CMath_SNORMtoUNORM_FLT2(SpotMeterTex);

            return SpotMeterTex;
        #else
            return Tex;
        #endif
    }

    void CCamera_ApplySpotMeterOverlay(inout float3 Color, in float2 UnormTex, in float3 NonExposedColor)
    {
        #if CCAMERA_TOGGLE_AUTO_EXPOSURE
            if ((_CCamera_MeteringType == 1) && _CCamera_ShowSpotMeterOverlay)
            {
                /*
                    Create a UV that represents a square texture.
                        Width conversion | [0, 1] -> [-N, N]
                        Height conversion | [0, 1] -> [-N, N]
                */
                float2 OverlayPos = UnormTex;
                OverlayPos -= float2(_CCamera_SpotMeterOffset.x, -_CCamera_SpotMeterOffset.y);
                OverlayPos /= _CCamera_SpotMeterScale;
                float2 DotPos = OverlayPos;

                // Shrink the UV so [-1, 1] fills a square
                #if BUFFER_WIDTH > BUFFER_HEIGHT
                    OverlayPos.x *= CSHADE_ASPECT_RATIO;
                #else
                    OverlayPos.y *= CSHADE_ASPECT_RATIO;
                #endif

                // Create the needed mask; output 1 if the texcoord is within square range
                float SquareMask = all(abs(OverlayPos) <= 1.0);

                // Shrink the UV so [-1, 1] fills a square
                #if BUFFER_WIDTH > BUFFER_HEIGHT
                    DotPos.x *= CSHADE_ASPECT_RATIO;
                #else
                    DotPos.y *= CSHADE_ASPECT_RATIO;
                #endif
                float DotMask = CMath_GetAntiAliasShape(length(DotPos), 0.1);

                // Apply square mask to output
                Color = lerp(Color, NonExposedColor.rgb, SquareMask);
                // Apply dot mask to output
                Color = lerp(1.0, Color, DotMask);
            }
        #endif
    }
#endif
