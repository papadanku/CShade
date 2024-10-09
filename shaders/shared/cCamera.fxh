
#if !defined(INCLUDE_CCAMERA)
    #define INCLUDE_CCAMERA

    // AutoExposure(): https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html

    float CCamera_GetLogLuminance(float3 Color)
    {
        float Luminance = max(max(Color.r, Color.g), Color.b);
        return log(max(Luminance, 1e-2));
    }

#endif
