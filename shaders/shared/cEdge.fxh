
#if !defined(INCLUDE_CEDGE)
    #define INCLUDE_CEDGE

    struct CEdge_Gradient
    {
        float4 Ix;
        float4 Iy;
    };

    float3 CEdge_GetMagnitudeRGB(float3 Ix, float3 Iy)
    {
        return sqrt((Ix.rgb * Ix.rgb) + (Iy.rgb * Iy.rgb));
    }

    CEdge_Gradient CEdge_GetDDXY(sampler2D Image, float2 Tex)
    {
        float4 Color = tex2D(Image, Tex);

        CEdge_Gradient Output;
        Output.Ix = ddx(Color);
        Output.Iy = ddy(Color);
        return Output;
    }

    CEdge_Gradient CEdge_GetBilinearSobel3x3(sampler2D Image, float2 Tex, float2 Delta)
    {
        const float P = 1.0 / 2.0;
        float4 Tex0 = Tex.xyxy + (float4(-P, -P, P, P) * Delta.xyxy);
        float4 A0 = tex2D(Image, Tex0.xw); // <-0.5, +0.5>
        float4 C0 = tex2D(Image, Tex0.zw); // <+0.5, +0.5>
        float4 A2 = tex2D(Image, Tex0.xy); // <-0.5, -0.5>
        float4 C2 = tex2D(Image, Tex0.zy); // <+0.5, -0.5>

        CEdge_Gradient Output;
        Output.Ix = (C0 + C2) - (A0 + A2);
        Output.Iy = (A0 + C0) - (A2 + C2);
        return Output;
    }

    CEdge_Gradient CEdge_GetBilinearPrewitt5x5(sampler2D Image, float2 Tex, float2 Delta)
    {
        // Sampler locations:
        // A0 B0 C0
        // A1    C1
        // A2 B2 C2
        float4 Tex1 = Tex.xyyy + (float4(-1.5, 1.5, 0.0, -1.5) * Delta.xyyy);
        float4 Tex2 = Tex.xyyy + (float4(0.0, 1.5, 0.0, -1.5) * Delta.xyyy);
        float4 Tex3 = Tex.xyyy + (float4(1.5, 1.5, 0.0, -1.5) * Delta.xyyy);

        float4 A0 = tex2D(Image, Tex1.xy) * 4.0; // <-1.5, +1.5>
        float4 A1 = tex2D(Image, Tex1.xz) * 2.0; // <-1.5,  0.0>
        float4 A2 = tex2D(Image, Tex1.xw) * 4.0; // <-1.5, -1.5>
        float4 B0 = tex2D(Image, Tex2.xy) * 2.0; // < 0.0, +1.5>
        float4 B2 = tex2D(Image, Tex2.xw) * 2.0; // < 0.0, -1.5>
        float4 C0 = tex2D(Image, Tex3.xy) * 4.0; // <+1.5, +1.5>
        float4 C1 = tex2D(Image, Tex3.xz) * 2.0; // <+1.5,  0.0>
        float4 C2 = tex2D(Image, Tex3.xw) * 4.0; // <+1.5, -1.5>

        CEdge_Gradient Output;
        Output.Ix = ((C0 + C1 + C2) - (A0 + A1 + A2)) / 10.0;
        Output.Iy = ((A0 + B0 + C0) - (A2 + B2 + C2)) / 10.0;
        return Output;
    }

    CEdge_Gradient CEdge_GetBilinearSobel5x5(sampler2D Image, float2 Tex, float2 Delta)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        // Sampler locations:
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float4 Tex1 = Tex.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) * Delta.xxyy);
        float4 Tex2 = Tex.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) * Delta.xxyy);

        float4 A0 = tex2D(Image, Tex1.xw) * 4.0; // <-1.5, +0.5>
        float4 A1 = tex2D(Image, Tex1.yw) * 4.0; // <+1.5, +0.5>
        float4 A2 = tex2D(Image, Tex1.xz) * 4.0; // <-1.5, -0.5>
        float4 B0 = tex2D(Image, Tex1.yz) * 4.0; // <+1.5, -0.5>
        float4 B1 = tex2D(Image, Tex2.xw) * 4.0; // <-0.5, +1.5>
        float4 B2 = tex2D(Image, Tex2.yw) * 4.0; // <+0.5, +1.5>
        float4 C0 = tex2D(Image, Tex2.xz) * 4.0; // <-0.5, -1.5>
        float4 C1 = tex2D(Image, Tex2.yz) * 4.0; // <+0.5, -1.5>

        CEdge_Gradient Output;
        Output.Ix = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;
        Output.Iy = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
        return Output;
    }

    CEdge_Gradient CEdge_GetBilinearPrewitt3x3(sampler2D Image, float2 Tex, float2 Delta)
    {
        const float P = 2.0 / 3.0;
        const float Normalize = 3.0 / 4.0;
        float4 Tex0 = Tex.xyxy + (float4(-P, -P, P, P) * Delta.xyxy);
        float4 A0 = tex2D(Image, Tex0.xw); // <-0.625, +0.625>
        float4 C0 = tex2D(Image, Tex0.zw); // <+0.625, +0.625>
        float4 A2 = tex2D(Image, Tex0.xy); // <-0.625, -0.625>
        float4 C2 = tex2D(Image, Tex0.zy); // <+0.625, -0.625>

        CEdge_Gradient Output;
        Output.Ix = ((C0 + C2) - (A0 + A2)) * Normalize;
        Output.Iy = ((A0 + C0) - (A2 + C2)) * Normalize;
        return Output;
    }

    CEdge_Gradient CEdge_GetBilinearScharr3x3(sampler2D Image, float2 Tex, float2 Delta)
    {
        const float P = 3.0 / 8.0;
        const float Normalize = 4.0 / 3.0;
        float4 Tex0 = Tex.xyxy + (float4(-P, -P, P, P) * Delta.xyxy);
        float4 A0 = tex2D(Image, Tex0.xw); // <-0.375, +0.375>
        float4 C0 = tex2D(Image, Tex0.zw); // <+0.375, +0.375>
        float4 A2 = tex2D(Image, Tex0.xy); // <-0.375, -0.375>
        float4 C2 = tex2D(Image, Tex0.zy); // <+0.375, -0.375>

        CEdge_Gradient Output;
        Output.Ix = ((C0 + C2) - (A0 + A2)) * Normalize;
        Output.Iy = ((A0 + C0) - (A2 + C2)) * Normalize;
        return Output;
    }

    struct CEdge_FreiChen
    {
        float Divisor;
        float Kernel[9];
    };

    /*
        Frei-Chen edge detection

        https://www.rastergrid.com/blog/2011/01/frei-chen-edge-detector/
    */

    float4 CEdge_GetFreiChen(sampler2D Image, float2 Tex, float2 Delta)
    {
        float4 Tex1 = Tex.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Delta.xyyy);
        float4 Tex2 = Tex.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Delta.xyyy);
        float4 Tex3 = Tex.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Delta.xyyy);

        float4 T[9];
        T[0] = tex2D(Image, Tex1.xy); // <-1.0, 1.0>
        T[1] = tex2D(Image, Tex2.xy); // <0.0, 1.0>
        T[2] = tex2D(Image, Tex3.xy); // <1.0, 1.0>
        T[3] = tex2D(Image, Tex1.xz); // <-1.0, 0.0>
        T[4] = tex2D(Image, Tex2.xz); // <0.0, 0.0>
        T[5] = tex2D(Image, Tex3.xz); // <1.0, 0.0>
        T[6] = tex2D(Image, Tex1.xw); // <-1.0, -1.0>
        T[7] = tex2D(Image, Tex2.xw); // <0.0, -1.0>
        T[8] = tex2D(Image, Tex3.xw); // <1.0, -1.0>

        CEdge_FreiChen Masks[9];

        Masks[0].Divisor = 1.0 / (2.0 * sqrt(2.0));
        Masks[0].Kernel =
        {
             1.0,  sqrt(2.0),  1.0,
             0.0,  0.0,        0.0,
            -1.0, -sqrt(2.0), -1.0
        };

        Masks[1].Divisor = 1.0 / (2.0 * sqrt(2.0));
        Masks[1].Kernel =
        {
            1.0,       0.0, -1.0,
            sqrt(2.0), 0.0, -sqrt(2.0),
            1.0,       0.0, -1.0
        };

        Masks[2].Divisor = 1.0 / (2.0 * sqrt(2.0));
        Masks[2].Kernel =
        {
             0.0,      -1.0,  sqrt(2.0),
             1.0,       0.0, -1.0,
            -sqrt(2.0), 1.0,  0.0
        };

        Masks[3].Divisor = 1.0 / (2.0 * sqrt(2.0));
        Masks[3].Kernel =
        {
            sqrt(2.0), -1.0,  0.0,
            -1.0,       0.0,  1.0,
             0.0,       1.0, -sqrt(2.0)
        };

        Masks[4].Divisor = 1.0 / 2.0;
        Masks[4].Kernel =
        {
             0.0, 1.0,  0.0,
            -1.0, 0.0, -1.0,
             0.0, 1.0,  0.0
        };

        Masks[5].Divisor = 1.0 / 2.0;
        Masks[5].Kernel =
        {
            -1.0, 0.0,  1.0,
             0.0, 0.0,  0.0,
             1.0, 0.0, -1.0
        };

        Masks[6].Divisor = 1.0 / 6.0;
        Masks[6].Kernel =
        {
             1.0, -2.0,  1.0,
            -2.0,  4.0, -2.0,
             1.0, -2.0,  1.0
        };

        Masks[7].Divisor = 1.0 / 6.0;
        Masks[7].Kernel =
        {
            -2.0, 1.0, -2.0,
             1.0, 4.0,  1.0,
            -2.0, 1.0, -2.0
        };

        Masks[8].Divisor = 1.0 / 3.0;
        Masks[8].Kernel =
        {
            1.0, 1.0, 1.0,
            1.0, 1.0, 1.0,
            1.0, 1.0, 1.0
        };

        float4 M = 0.0;
        float4 S = 0.0;

        // Compute M
        [unroll]
        for (int i = 0; i < 9; i++)
        {
            float4 G = 0.0;

            [unroll]
            for (int j = 0; j < 9; j++)
            {
                G += T[j] * (Masks[i].Kernel[j]);
            }
            G *= Masks[i].Divisor;
            G *= G;

            if (i < 4)
            {
                M += G;
            }
            else
            {
                S += G;
            }
        }

        // Compute S
        S += M;

        return sqrt(M / S);
    }

#endif
