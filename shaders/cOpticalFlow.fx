
namespace OpticalFlow
{
    /*
        [Shader parameters]
    */

    #define OPTION(DATA_TYPE, NAME, TYPE, CATEGORY, LABEL, MINIMUM, MAXIMUM, DEFAULT) \
        uniform DATA_TYPE NAME < \
            ui_type = TYPE; \
            ui_category = CATEGORY; \
            ui_label = LABEL; \
            ui_min = MINIMUM; \
            ui_max = MAXIMUM; \
        > = DEFAULT;

    OPTION(float, _MipBias, "slider", "Optical flow", "Optical flow mipmap bias", 0.0, 6.0, 0.0)
    OPTION(float, _BlendFactor, "slider", "Optical flow", "Temporal blending factor", 0.0, 0.9, 0.2)

    /*
        [Macros for resolution sizes and scaling]
    */

    #define FP16_SMALLEST_SUBNORMAL float((1.0 / (1 << 14)) * (0.0 + (1.0 / (1 << 10))))

    #define ROUND_UP_EVEN(x) int(x) + (int(x) % 2)

    #define BUFFER_SIZE_0 int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1)
    #define BUFFER_SIZE_1 int2(BUFFER_SIZE_0 >> 1)
    #define BUFFER_SIZE_2 int2(BUFFER_SIZE_1 >> 1)
    #define BUFFER_SIZE_3 int2(BUFFER_SIZE_2 >> 1)
    #define BUFFER_SIZE_4 int2(BUFFER_SIZE_3 >> 1)

    /*
        [Textures and samplers]
    */

    #define CREATE_TEXTURE(NAME, SIZE, FORMAT, LEVELS) \
        texture2D NAME \
        { \
            Width = SIZE.x; \
            Height = SIZE.y; \
            Format = FORMAT; \
            MipLevels = LEVELS; \
        };

    #define CREATE_SAMPLER(NAME, TEXTURE) \
        sampler2D NAME \
        { \
            Texture = TEXTURE; \
            AddressU = MIRROR; \
            AddressV = MIRROR; \
            MagFilter = LINEAR; \
            MinFilter = LINEAR; \
            MipFilter = LINEAR; \
        };

    texture2D Render_Color : COLOR;

    sampler2D Sample_Color
    {
        Texture = Render_Color;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    CREATE_TEXTURE(Render_Common_0, BUFFER_SIZE_0, RG8, 2)
    CREATE_SAMPLER(Sample_Common_0, Render_Common_0)

    CREATE_TEXTURE(Render_Common_1_A, BUFFER_SIZE_1, RGBA16F, 8)
    CREATE_SAMPLER(Sample_Common_1_A, Render_Common_1_A)

    CREATE_TEXTURE(Render_Common_1_B, BUFFER_SIZE_1, RG16F, 8)
    CREATE_SAMPLER(Sample_Common_1_B, Render_Common_1_B)

    CREATE_TEXTURE(Render_Common_1_C, BUFFER_SIZE_1, RG16F, 8)
    CREATE_SAMPLER(Sample_Common_1_C, Render_Common_1_C)

    CREATE_TEXTURE(Render_Optical_Flow, BUFFER_SIZE_1, RG16F, 1)
    CREATE_SAMPLER(Sample_Optical_Flow, Render_Optical_Flow)

    CREATE_TEXTURE(Render_Common_2, BUFFER_SIZE_2, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_2, Render_Common_2)

    CREATE_TEXTURE(Render_Common_3, BUFFER_SIZE_3, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_3, Render_Common_3)
    
    CREATE_TEXTURE(Render_Common_4, BUFFER_SIZE_4, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_4, Render_Common_4)

    /*
        [Vertex shaders]
    */

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    void Derivatives_Spatial_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 LocalTexCoord = 0.0;
        Basic_VS(ID, Position, LocalTexCoord);
        TexCoords[0] = LocalTexCoord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        TexCoords[1] = LocalTexCoord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
    }

    static const float4 BlurOffsets[3] =
    {
        float4(0.0, 1.490652, 3.4781995, 5.465774),
        float4(0.0, 7.45339, 9.441065, 11.42881),
        float4(0.0, 13.416645, 15.404578, 17.392626)
    };

    void Blur_VS(in bool IsAlt, in float2 PixelSize, in uint ID, out float4 Position, out float4 TexCoords[7])
    {
        TexCoords[0] = 0.0;
        Basic_VS(ID, Position, TexCoords[0].xy);
        if (!IsAlt)
        {
            TexCoords[1] = TexCoords[0].xyyy + (BlurOffsets[0].xyzw / PixelSize.xyyy);
            TexCoords[2] = TexCoords[0].xyyy + (BlurOffsets[1].xyzw / PixelSize.xyyy);
            TexCoords[3] = TexCoords[0].xyyy + (BlurOffsets[2].xyzw / PixelSize.xyyy);
            TexCoords[4] = TexCoords[0].xyyy - (BlurOffsets[0].xyzw / PixelSize.xyyy);
            TexCoords[5] = TexCoords[0].xyyy - (BlurOffsets[1].xyzw / PixelSize.xyyy);
            TexCoords[6] = TexCoords[0].xyyy - (BlurOffsets[2].xyzw / PixelSize.xyyy);
        }
        else
        {
            TexCoords[1] = TexCoords[0].xxxy + (BlurOffsets[0].yzwx / PixelSize.xxxy);
            TexCoords[2] = TexCoords[0].xxxy + (BlurOffsets[1].yzwx / PixelSize.xxxy);
            TexCoords[3] = TexCoords[0].xxxy + (BlurOffsets[2].yzwx / PixelSize.xxxy);
            TexCoords[4] = TexCoords[0].xxxy - (BlurOffsets[0].yzwx / PixelSize.xxxy);
            TexCoords[5] = TexCoords[0].xxxy - (BlurOffsets[1].yzwx / PixelSize.xxxy);
            TexCoords[6] = TexCoords[0].xxxy - (BlurOffsets[2].yzwx / PixelSize.xxxy);
        }
    }

    #define CREATE_BLUR_VS(NAME, IS_ALT, PIXEL_SIZE) \
        void NAME(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[7] : TEXCOORD0) \
        { \
            Blur_VS(IS_ALT, PIXEL_SIZE, ID, Position, TexCoords); \
        }

    CREATE_BLUR_VS(Blur_0_VS, false, BUFFER_SIZE_1)
    CREATE_BLUR_VS(Blur_1_VS, true, BUFFER_SIZE_1)

    void Level_VS(in uint ID, in float2 TexelSize, out float4 Position, out float4 TexCoords[4])
    {
        float2 LocalTexCoord = 0.0;
        Basic_VS(ID, Position, LocalTexCoord);
        TexCoords[0] = LocalTexCoord.xxyy + (float4(-1.5, -0.5, 0.5, 1.5) / TexelSize.xxyy);
        TexCoords[1] = LocalTexCoord.xxyy + (float4(0.5, 1.5, 0.5, 1.5) / TexelSize.xxyy);
        TexCoords[2] = LocalTexCoord.xxyy + (float4(-1.5, -0.5, -0.5, -1.5) / TexelSize.xxyy);
        TexCoords[3] = LocalTexCoord.xxyy + (float4(0.5, 1.5, -0.5, -1.5) / TexelSize.xxyy);
    }

    #define CREATE_LEVEL_VS(NAME, BUFFER_SIZE) \
        void NAME(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[4] : TEXCOORD0) \
        { \
            Level_VS(ID, BUFFER_SIZE, Position, TexCoords); \
        }

    CREATE_LEVEL_VS(LK_Level_1_VS, BUFFER_SIZE_1)
    CREATE_LEVEL_VS(LK_Level_2_VS, BUFFER_SIZE_2)
    CREATE_LEVEL_VS(LK_Level_3_VS, BUFFER_SIZE_3)
    CREATE_LEVEL_VS(LK_Level_4_VS, BUFFER_SIZE_4)

    /*
        [Pixel shaders]
    */

    void Normalize_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float2 Color : SV_TARGET0)
    {
        float4 LocalColor = max(tex2D(Sample_Color, TexCoord), exp2(-10.0));
        Color = saturate(LocalColor.rgb.xy / dot(LocalColor.rgb, 1.0));
    }

    static const float BlurWeights[10] =
    {
        0.06299088,
        0.122137636, 0.10790718, 0.08633988,
        0.062565096, 0.04105926, 0.024403222,
        0.013135255, 0.006402994, 0.002826693
    };

    void Gaussian_Blur(in sampler2D Source, in float4 TexCoords[7], bool Alt, out float4 OutputColor0)
    {
        float TotalWeights = BlurWeights[0];
        OutputColor0 = (tex2D(Source, TexCoords[0].xy) * BlurWeights[0]);

        int CoordIndex = 1;
        int WeightIndex = 1;

        while(CoordIndex < 4)
        {
            if(!Alt)
            {
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xy) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xz) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xw) * BlurWeights[WeightIndex + 2]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xy) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xz) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xw) * BlurWeights[WeightIndex + 2]);
            }
            else
            {
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xw) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].yw) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].zw) * BlurWeights[WeightIndex + 2]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xw) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].yw) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].zw) * BlurWeights[WeightIndex + 2]);
            }

            CoordIndex = CoordIndex + 1;
            WeightIndex = WeightIndex + 3;
        }

        for(int i = 1; i < 10; i++)
        {
            TotalWeights += (BlurWeights[i] * 2.0);
        }

        OutputColor0 = OutputColor0 / TotalWeights;
    }

    void Pre_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Common_0, TexCoords, false, OutputColor0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Common_1_B, TexCoords, true, OutputColor0);
    }

    void Derivatives_Temporal_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
    {
        float2 I0 = tex2D(Sample_Common_1_C, TexCoord).xy;
        float2 I1 = tex2D(Sample_Common_1_A, TexCoord).xy;
        OutputColor0 = I0 - I1;
    }

    void Copy_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Sample_Common_1_A, TexCoord);
    }

    void Derivatives_Spatial_PS(in float4 Position : SV_POSITION, in float4 TexCoords[2] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(Sample_Common_1_C, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(Sample_Common_1_C, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(Sample_Common_1_C, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(Sample_Common_1_C, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(Sample_Common_1_C, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(Sample_Common_1_C, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(Sample_Common_1_C, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(Sample_Common_1_C, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

        OutputColor0 = 0.0;
        OutputColor0.xy = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;
        OutputColor0.zw = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
    }

    float2 Lucas_Kanade(int Level, float2 Vectors, float4 TexCoords[4])
    {
        /*
            Calculate Lucas-Kanade optical flow by solving (A^-1 * B)
            [A11 A12]^-1 [-B1] -> [ A11 -A12] [-B1]
            [A21 A22]^-1 [-B2] -> [-A21  A22] [-B2]
            A11 = Ix^2
            A12 = IxIy
            A21 = IxIy
            A22 = Iy^2
            B1 = IxIt
            B2 = IyIt
        */

        // The spatial(S) and temporal(T) derivative neighbors to sample
        const int WindowSize = 16;
        float4 S[WindowSize];
        float2 T[WindowSize];

        // Windows matrices to sum
        float3 A = 0.0;
        float2 B = 0.0;

        float2 WindowCoords[WindowSize] =
        {
            TexCoords[0].xz, TexCoords[0].xw, TexCoords[0].yz, TexCoords[0].yw,
            TexCoords[1].xz, TexCoords[1].xw, TexCoords[1].yz, TexCoords[1].yw,
            TexCoords[2].xz, TexCoords[2].xw, TexCoords[2].yz, TexCoords[2].yw,
            TexCoords[3].xz, TexCoords[3].xw, TexCoords[3].yz, TexCoords[3].yw,
        };

        [unroll] for (int i = 0; i < WindowSize; i++)
        {
            // S[i].x = IxR; S[i].y = IxG; S[i].z = IyR; S[i].w = IyG;
            S[i] = tex2D(Sample_Common_1_A, WindowCoords[i]).xyzw;

            // T[i].r = ItR; T[i].g = ItG;
            T[i] = tex2D(Sample_Common_1_B, WindowCoords[i]).rg;

            // A.x = A11; A.y = A22; A.z = A12/A22
            A.xyz += (S[i].xzx * S[i].xzz);
            A.xyz += (S[i].ywy * S[i].yww);

            // B.x = B1; B.y = B2
            B.xy += (S[i].xz * T[i].rr);
            B.xy += (S[i].yw * T[i].gg);
        }

        // Make determinant non-zero
        A.xy = max(A.xy, FP16_SMALLEST_SUBNORMAL);

        // Create -IxIy (A12) for A^-1 and its determinant
        A.z = A.z * (-1.0);

        // Calculate A^-1 determinant
        float D = ((A.x * A.y) - (A.z * A.z));

        // Solve A^-1
        A = (1.0 / D) * A;

        // Calculate Lucas-Kanade matrix
        float2 LK = 0.0;
        LK.x = dot(A.yz, -B.xy);
        LK.y = dot(A.zx, -B.xy);

        // Propagate (add) vectors
        LK = (D != 0.0) ? Vectors + LK : 0.0;

        // Do not multiply on the finest level
        LK = (Level > 0) ? LK * 2.0 : LK;
        return LK;
    }

    float2 Average_UV(sampler2D Source, float4 TexCoords[4])
    {
        const int WindowSize = 4;

        float2 WindowCoords[WindowSize] =
        {
            TexCoords[0].yz, TexCoords[1].xz,
            TexCoords[2].yz, TexCoords[3].xz,
        };

        float2 Color = 0.0;

        for (int i = 0; i < WindowSize; i++)
        {
            Color += tex2D(Source, WindowCoords[i]).xy;
        }

        return Color / 4.0;
    }

    void LK_Level_4_PS(in float4 Position : SV_POSITION, in float4 TexCoords[4] : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Color = float4(Lucas_Kanade(3, 0.0, TexCoords), 0.0, 1.0);
    }
    
    void LK_Level_3_PS(in float4 Position : SV_POSITION, in float4 TexCoords[4] : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Color = float4(Lucas_Kanade(2, Average_UV(Sample_Common_4, TexCoords).xy, TexCoords), 0.0, 1.0);
    }

    void LK_Level_2_PS(in float4 Position : SV_POSITION, in float4 TexCoords[4] : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Color = float4(Lucas_Kanade(1, Average_UV(Sample_Common_3, TexCoords).xy, TexCoords), 0.0, 1.0);
    }

    void LK_Level_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[4] : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Color = float4(Lucas_Kanade(0, Average_UV(Sample_Common_2, TexCoords).xy, TexCoords), 0.0, _BlendFactor);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Optical_Flow, TexCoords, false, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Common_1_B, TexCoords, true, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Display_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        OutputColor0 = 0.0;
        float2 Velocity = tex2Dlod(Sample_Common_1_A, float4(TexCoord, 0.0, _MipBias)).xy;
        float VelocityLength = saturate(rsqrt(dot(Velocity, Velocity)));
        OutputColor0.rg = (Velocity * VelocityLength) * 0.5 + 0.5;
        OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
        OutputColor0.rgb /= max(max(OutputColor0.x, OutputColor0.y), OutputColor0.z);
    }

    #define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
        pass \
        { \
            VertexShader = VERTEX_SHADER; \
            PixelShader = PIXEL_SHADER; \
            RenderTarget0 = RENDER_TARGET; \
        }

    technique cOpticalFlow
    {
        // Normalize current frame
        CREATE_PASS(Basic_VS, Normalize_PS, Render_Common_0)

        // Pre-process Gaussian blur
        CREATE_PASS(Blur_0_VS, Pre_Blur_0_PS, Render_Common_1_B)
        CREATE_PASS(Blur_1_VS, Pre_Blur_1_PS, Render_Common_1_A) // Save this to store later

        // Calculate temporal derivative pyramids
        CREATE_PASS(Basic_VS, Derivatives_Temporal_PS, Render_Common_1_B)

        // Copy current convolved frame for next frame
        CREATE_PASS(Basic_VS, Copy_PS, Render_Common_1_C)

        // Calculate spatial derivative pyramids
        CREATE_PASS(Derivatives_Spatial_VS, Derivatives_Spatial_PS, Render_Common_1_A)

        // Bilinear Lucas-Kanade Optical Flow
        CREATE_PASS(LK_Level_4_VS, LK_Level_4_PS, Render_Common_4)
        CREATE_PASS(LK_Level_3_VS, LK_Level_3_PS, Render_Common_3)
        CREATE_PASS(LK_Level_2_VS, LK_Level_2_PS, Render_Common_2)
        pass
        {
            VertexShader = LK_Level_1_VS;
            PixelShader = LK_Level_1_PS;
            RenderTarget0 = Render_Optical_Flow;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Post-process Gaussian blur
        CREATE_PASS(Blur_0_VS, Post_Blur_0_PS, Render_Common_1_B)
        CREATE_PASS(Blur_1_VS, Post_Blur_1_PS, Render_Common_1_A)

        // Display
        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Display_PS;
        }
    }
}
