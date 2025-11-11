
#include "cMath.fxh"

#if !defined(INCLUDE_CCAMERA_OUTPUT)
    #define INCLUDE_CCAMERA_OUTPUT

    uniform float _CCamera_ExposureSmoothingSpeed <
        ui_category_closed = true;
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_text = "Exposure Settings";
        ui_label = "Auto Exposure Smoothing Speed";
        ui_type = "slider";
        ui_min = 0.1;
        ui_max = 1.0;
        ui_tooltip = "Controls how quickly the auto-exposure adapts to changes in scene luminance.";
    > = 0.25;

    uniform float _CCamera_ExposureBias <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Auto Exposure Compensation Bias";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = -4.0;
        ui_max = 4.0;
        ui_tooltip = "Applies a manual compensation bias to the auto-exposure, adjusting the overall brightness.";
    > = 1.0;

    uniform float _CCamera_ExposureRange <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Auto Exposure Compensation Range";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = 1.0;
        ui_max = 4.0;
        ui_tooltip = "Defines the maximum range (in f-stops) that the auto-exposure can adjust the scene brightness.";
    > = 1.0;

    uniform int _CCamera_MeteringType <
        ui_category_closed = true;
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Auto Exposure Adaptation Method";
        ui_type = "combo";
        ui_items = "Average Metering\0Spot Metering\0";
        ui_tooltip = "Selects the method for auto-exposure adaptation: either average metering across the whole scene or spot metering on a specific area.";
    > = 0;

    uniform bool _CCamera_LumaMeter <
        ui_text = "\n[Tools] Luminance Metering";
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Show Luminance Meter Overlay";
        ui_type = "radio";
        ui_tooltip = "When enabled, displays an overlay that visualizes the scene's luminance levels.";
    > = false;

    uniform float _CCamera_LumaMeterScale <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Scale";
        ui_type = "slider";
        ui_min = 1e-3;
        ui_max = 1.0;
        ui_tooltip = "Controls the size or scale of the luminance meter overlay.";
    > = 0.75;

    uniform float2 _CCamera_LumaMeterOffset <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
        ui_tooltip = "Adjusts the horizontal and vertical position of the luminance meter overlay.";
    > = float2(0.0, -0.25);

    uniform bool _CCamera_ShowSpotMeterOverlay <
        ui_text = "\n[Tools] Spot Metering";
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Show Spot Meter Area Overlay";
        ui_type = "radio";
        ui_tooltip = "When enabled, displays an overlay indicating the area used for spot metering.";
    > = false;

    uniform float _CCamera_SpotMeterScale <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Scale";
        ui_type = "slider";
        ui_min = 1e-3;
        ui_max = 1.0;
        ui_tooltip = "Controls the size or scale of the spot metering area.";
    > = 0.5;

    uniform float2 _CCamera_SpotMeterOffset <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Spot Meter Area Position Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
        ui_tooltip = "Adjusts the horizontal and vertical position of the spot metering area.";
    > = 0.0;

    uniform bool _CCamera_ExposurePeaking <
        ui_text = "\n[Tools] Exposure Peaking";
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Show Exposure Peaking Overlay";
        ui_type = "radio";
        ui_tooltip = "When enabled, displays an overlay that highlights areas within a specified exposure threshold.";
    > = false;

    uniform int _CCamera_ExposurePeakingDitherType <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Exposure Peaking Dither Algorithm";
        ui_type = "combo";
        ui_items = "Golden Ratio Noise\0Interleaved Gradient Noise\0White Noise\0Disabled\0";
        ui_tooltip = "Selects the dither algorithm used for the exposure peaking overlay.";
    > = 0;

    uniform float3 _CCamera_ExposurePeakingThreshold <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Exposure Peaking Luminance Threshold";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
        ui_tooltip = "Sets the luminance threshold for exposure peaking, highlighting areas above this level.";
    > = float3(1.0, 1.0, 1.0);

    uniform int _CCamera_ExposurePeakingCellWidth <
        ui_category = "Pipeline / Output / Auto Exposure";
        ui_label = "Exposure Peaking Cell Size";
        ui_type = "slider";
        ui_min = 1;
        ui_max = 16;
        ui_tooltip = "Sets the width of the cells in the checkerboard pattern used for exposure peaking.";
    > = 8;

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html
    float CCamera_GetLogLuminance(float3 Color)
    {
        float Luminance = max(max(Color.r, Color.g), Color.b);
        return log(max(Luminance, 1e-2));
    }

    float4 CCamera_CreateExposureTex(float Luminance, float FrameTime)
    {
        // .rgb = Output the highest brightness out of red/green/blue component
        // .a = Output the weight for Temporal Smoothing
        float Delay = 1e-3 * FrameTime;
        return float4((float3)Luminance, saturate(Delay * _CCamera_ExposureSmoothingSpeed));
    }

    struct Exposure
    {
        float ExpLuma;
        float Ev100;
        float Value;
    };

    Exposure CCamera_GetExposureData(float LumaTex)
    {
        Exposure Output;
        Output.ExpLuma = exp(LumaTex);
        Output.Ev100 = log2(Output.ExpLuma * 100.0 / 12.5);
        Output.Ev100 -= _CCamera_ExposureBias; // optional manual bias
        Output.Ev100 = clamp(Output.Ev100, -_CCamera_ExposureRange, _CCamera_ExposureRange);
        Output.Value = 1.0 / (1.2 * exp2(Output.Ev100));
        return Output;
    }

    float3 CCamera_ApplyAutoExposure(float3 Color, Exposure Input)
    {
        return Color * Input.Value;
    }

    void CCamera_ApplyAverageLumaOverlay(inout float3 Color, in float2 UnormTex, in Exposure E)
    {
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
    }

    // Exposure-specific functions
    float2 CCamera_GetSpotMeterTex(float2 Tex)
    {
        // For spot-metering, we fill the target square texture with the region only
        float2 SpotMeterTex = CMath_UNORMtoSNORM_FLT2(Tex);

        // Expand the UV so [-1, 1] fills the shape of its input texture instead of output
        #if BUFFER_WIDTH > BUFFER_HEIGHT
            SpotMeterTex.x /= ASPECT_RATIO;
        #else
            SpotMeterTex.y /= ASPECT_RATIO;
        #endif

        SpotMeterTex *= _CCamera_SpotMeterScale;
        SpotMeterTex += float2(_CCamera_SpotMeterOffset.x, -_CCamera_SpotMeterOffset.y);
        SpotMeterTex = CMath_SNORMtoUNORM_FLT2(SpotMeterTex);

        return SpotMeterTex;
    }

    void CCamera_ApplySpotMeterOverlay(inout float3 Color, in float2 UnormTex, in float3 NonExposedColor)
    {
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
                OverlayPos.x *= ASPECT_RATIO;
            #else
                OverlayPos.y *= ASPECT_RATIO;
            #endif

            // Create the needed mask; output 1 if the texcoord is within square range
            float SquareMask = all(abs(OverlayPos) <= 1.0);

            // Shrink the UV so [-1, 1] fills a square
            #if BUFFER_WIDTH > BUFFER_HEIGHT
                DotPos.x *= ASPECT_RATIO;
            #else
                DotPos.y *= ASPECT_RATIO;
            #endif
            float DotMask = CMath_GetAntiAliasShape(length(DotPos), 0.1);

            // Apply square mask to output
            Color = lerp(Color, NonExposedColor.rgb, SquareMask);
            // Apply dot mask to output
            Color = lerp(1.0, Color, DotMask);
        }
    }

    void CCAmera_ApplyExposurePeaking(inout float3 Color, in float2 Pos)
    {
        if (_CCamera_ExposurePeaking)
        {
            // Create the checkerboard
            float2 Grid = Pos / _CCamera_ExposurePeakingCellWidth;
            float3 Checkerboard = frac(dot(floor(Grid), 0.5)) * 2.0;

            // Compute our dithered thresholds
            float Hash = 0.0;

            switch (_CCamera_ExposurePeakingDitherType)
            {
                case 0:
                    Hash = CMath_GetGoldenRatioNoise(Pos);
                    break;
                case 1:
                    Hash = CMath_GetInterleavedGradientNoise(Pos);
                    break;
                case 2:
                    Hash = CMath_GetHash_FLT1(Pos, 0.0);
                    break;
                default:
                    Hash = 0.0;
                    break;
            }

            float3 Threshold = _CCamera_ExposurePeakingThreshold + Hash;
            Color = lerp(Color, Checkerboard, Color > Threshold);
        }
    }

#endif
