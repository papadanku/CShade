#include "cGraphics.fxh"

#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

    struct Texel
    {
        float2 MainTex;
        float2 Size;
        float2 LOD;
    };

    float4 SampleBlock(sampler2D Source, Texel Tex, float2 Vectors)
    {
        // Pack normalization and masking into 1 operation
        float4 Mask = float4(1.0, 1.0, 0.0, 0.0) * abs(Tex.Size.xyyy);
        float4 HalfPixel = (Tex.MainTex.xxyy + Vectors.xxyy) + float4(-0.5, 0.5, -0.5, 0.5);

        float4 OutputColor = 0.0;
        OutputColor.x = tex2Dlod(Source, (HalfPixel.xzzz * Mask) + Tex.LOD.xxxy);
        OutputColor.y = tex2Dlod(Source, (HalfPixel.xwww * Mask) + Tex.LOD.xxxy);
        OutputColor.z = tex2Dlod(Source, (HalfPixel.yzzz * Mask) + Tex.LOD.xxxy);
        OutputColor.w = tex2Dlod(Source, (HalfPixel.ywww * Mask) + Tex.LOD.xxxy);

        return OutputColor;
    }

    float GetMSE(float4 P, float4 C)
    {
        return sqrt(dot(pow(abs(P - C), 2.0), 1.0));
    }

    // [-1.0, 1.0] -> [Width, Height]
    float2 DecodeVectors(float2 Vectors, float2 ImageSize)
    {
        return Vectors / abs(ImageSize);
    }

    // [Width, Height] -> [-1.0, 1.0]
    float2 EncodeVectors(float2 Vectors, float2 ImageSize)
    {
        return clamp(Vectors * abs(ImageSize), -1.0, 1.0);
    }

    float2 GetPixelMFlow
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0_G,
        sampler2D SampleI0,
        sampler2D SampleI1,
        int Level,
        bool Fine
    )
    {
        // Setup constants
        const int WindowSize = 9;

        // Calculate main texel information (TexelSize, TexelLOD)
        Texel TexInfo;
        TexInfo.Size.x = ddx(MainTex.x);
        TexInfo.Size.y = ddy(MainTex.y);
        TexInfo.MainTex = MainTex * (1.0 / abs(TexInfo.Size));
        TexInfo.LOD = float2(0.0, float(Level));

        // Decode written vectors from coarser level
        Vectors = DecodeVectors(Vectors, TexInfo.Size);

        // Initialize variables
        float2 NewVectors = 0.0;
        float T = (Fine) ? 0.0 : 0.0001 * exp2(Level);
        float4 PSAD = SampleBlock(SampleI0, TexInfo, Vectors);
        float4 CSAD = SampleBlock(SampleI1, TexInfo, Vectors);
        float IMatch = abs(GetMSE(PSAD, CSAD)) - T;
        float Match = 0.0;


        // Calculate one-step search
        for (int x = -1; x <= 1; x++)
        for (int y = -1; y <= 1; y++)
        {
            if (all(int2(x, y) == 0))
                continue;

            float2 Shift = float2(x, y);
            CSAD = SampleBlock(SampleI1, TexInfo, Vectors + Shift);
            float CMatch = GetMSE(PSAD, CSAD);
            if (abs(CMatch) < IMatch)
            {
                Match = CMatch;
                NewVectors += Shift;
            }
        }

        // Propagate and encode vectors
        return EncodeVectors(Vectors + NewVectors, TexInfo.Size);
    }
#endif
