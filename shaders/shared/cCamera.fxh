
#if !defined(INCLUDE_CCAMERA_OUTPUT)
    #define INCLUDE_CCAMERA_OUTPUT

    uniform float _CCameraExposureSmoothingSpeed <
        ui_category_closed = true;
        ui_category = "Pipeline · Output · Auto Exposure";
        ui_label = "Smoothing Speed";
        ui_type = "slider";
        ui_min = 0.1;
        ui_max = 1.0;
    > = 0.25;

    uniform float _CCameraExposureBias <
        ui_category = "Pipeline · Output · Auto Exposure";
        ui_label = "Compensation Bias";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = -4.0;
        ui_max = 4.0;
    > = 1.0;

    uniform float _CCameraExposureRange <
        ui_category = "Pipeline · Output · Auto Exposure";
        ui_label = "Compensation Range";
        ui_type = "slider";
        ui_step = 0.001;
        ui_min = 1.0;
        ui_max = 4.0;
    > = 1.0;

    uniform int _CCameraMeteringType <
        ui_category_closed = true;
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Adaptation";
        ui_type = "combo";
        ui_items = "Average Metering\0Spot Metering\0";
    > = 0;

    uniform bool _CCameraLumaMeter <
        ui_text = "\nLuminance Metering";
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Display Luminance Meter";
        ui_type = "radio";
    > = false;

    uniform float _CCameraLumaMeterScale <
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Scale";
        ui_type = "slider";
        ui_min = 1e-3;
        ui_max = 1.0;
    > = 0.75;

    uniform float2 _CCameraLumaMeterOffset <
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = float2(0.0, -0.25);

    uniform bool _CCameraShowSpotMeterOverlay <
        ui_text = "\nSpot Metering";
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Display Spot Meter Area";
        ui_type = "radio";
    > = false;

    uniform float _CCameraSpotMeterScale <
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Scale";
        ui_type = "slider";
        ui_min = 1e-3;
        ui_max = 1.0;
    > = 0.5;

    uniform float2 _CCameraSpotMeterOffset <
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Offset";
        ui_type = "slider";
        ui_min = -1.0;
        ui_max = 1.0;
    > = 0.0;

    uniform bool _CCameraExposurePeaking <
        ui_text = "\nExposure Peaking";
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Display Peaking Cells";
        ui_type = "radio";
    > = false;

    uniform float3 _CCameraExposurePeakingThreshold <
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Threshold";
        ui_type = "slider";
        ui_min = 0.0;
        ui_max = 1.0;
    > = float3(1.0, 1.0, 1.0);

    uniform int _CCameraExposurePeakingCellWidth <
        ui_category = "Pipeline · Output · Auto Exposure · Tools";
        ui_label = "Cell Size";
        ui_type = "slider";
        ui_min = 1;
        ui_max = 16;
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
        return float4((float3)Luminance, saturate(Delay * _CCameraExposureSmoothingSpeed));
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
        Output.Ev100 -= _CCameraExposureBias; // optional manual bias
        Output.Ev100 = clamp(Output.Ev100, -_CCameraExposureRange, _CCameraExposureRange);
        Output.Value = 1.0 / (1.2 * exp2(Output.Ev100));
        return Output;
    }

    float3 CCamera_ApplyAutoExposure(float3 Color, Exposure Input)
    {
        return Color * Input.Value;
    }

    void CCamera_ApplyAverageLumaOverlay(inout float3 Color, in float2 UnormTex, in Exposure E)
    {
        if (_CCameraLumaMeter)
        {
            // Maps texture coordinates less-than/equal to the brightness.
            // We use [-1,-1] texture coordinates and bias them by 0.5 to have 0.0 be at the middle-left of the screen.
            UnormTex /= _CCameraLumaMeterScale;
            UnormTex += float2(-_CCameraLumaMeterOffset.x, _CCameraLumaMeterOffset.y);

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

        SpotMeterTex *= _CCameraSpotMeterScale;
        SpotMeterTex += float2(_CCameraSpotMeterOffset.x, -_CCameraSpotMeterOffset.y);
        SpotMeterTex = CMath_SNORMtoUNORM_FLT2(SpotMeterTex);

        return SpotMeterTex;
    }

    void CCamera_ApplySpotMeterOverlay(inout float3 Color, in float2 UnormTex, in float3 NonExposedColor)
    {
        if ((_CCameraMeteringType == 1) && _CCameraShowSpotMeterOverlay)
        {
            /*
                Create a UV that represents a square texture.
                    Width conversion | [0, 1] -> [-N, N]
                    Height conversion | [0, 1] -> [-N, N]
            */
            float2 OverlayPos = UnormTex;
            OverlayPos -= float2(_CCameraSpotMeterOffset.x, -_CCameraSpotMeterOffset.y);
            OverlayPos /= _CCameraSpotMeterScale;
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
        if (_CCameraExposurePeaking)
        {
            float2 Grid = Pos / _CCameraExposurePeakingCellWidth;
            float3 Checkerboard = frac(dot(floor(Grid), 0.5)) * 2.0;
            float3 Mask = smoothstep(_CCameraExposurePeakingThreshold * 0.9, _CCameraExposurePeakingThreshold, Color);
            Color = lerp(Color, Checkerboard, Mask);
        }
    }

#endif
