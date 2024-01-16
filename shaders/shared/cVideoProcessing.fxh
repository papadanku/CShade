#include "cGraphics.fxh"
#include "cImageProcessing.fxh"

#if !defined(CVIDEOPROCESSING_FXH)
    #define CVIDEOPROCESSING_FXH

    /*
        [Functions]
    */

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

    /*
        Lucas-Kanade optical flow with bilinear fetches
        ---
        Calculate Lucas-Kanade optical flow by solving (A^-1 * B)
        [A11 A12]^-1 [-B1] -> [ A11/D -A12/D] [-B1]
        [A21 A22]^-1 [-B2] -> [-A21/D  A22/D] [-B2]
        ---
        [ Ix^2/D -IxIy/D] [-IxIt]
        [-IxIy/D  Iy^2/D] [-IyIt]
    */

    float2 GetPixelPyLK
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleI0,
        sampler2D SampleI1
    )
    {
        // Initialize variables
        float4 WarpTex;
        float IxIx = 0.0;
        float IyIy = 0.0;
        float IxIy = 0.0;
        float IxIt = 0.0;
        float IyIt = 0.0;

        // Get required data to calculate main texel data
        const float Pi2 = acos(-1.0) * 2.0;

        // Calculate main texel data (TexelSize, TexelLOD)
        WarpTex = float4(MainTex, MainTex + Vectors);

        // Get gradient information
        float4 TexIx = ddx(WarpTex);
        float4 TexIy = ddy(WarpTex);
        float2 PixelSize = abs(TexIx.xy) + abs(TexIy.xy);

        // Un-normalize data for processing
        WarpTex *= (1.0 / abs(PixelSize.xyxy));
        Vectors = DecodeVectors(Vectors, PixelSize);

        [loop] for(int i = 1; i < 4; ++i)
        {
            [loop] for(int j = 0; j < 4 * i; ++j)
            {
                float Shift = (Pi2 / (4.0 * float(i))) * float(j);
                float2 AngleShift = 0.0;
                sincos(Shift, AngleShift.x, AngleShift.y);
                float4 Tex = WarpTex + (AngleShift.xyxy * float(i));

                // Get spatial gradient
                float4 NS = (Tex.xyxy + float4(0.0, -1.0, 0.0, 1.0)) * PixelSize.xyxy;
                float4 EW = (Tex.xyxy + float4(-1.0, 0.0, 1.0, 0.0)) * PixelSize.xyxy;
                float2 N = tex2Dgrad(SampleI0, NS.xy, TexIx.xy, TexIy.xy).rg;
                float2 S = tex2Dgrad(SampleI0, NS.zw, TexIx.xy, TexIy.xy).rg;
                float2 E = tex2Dgrad(SampleI0, EW.xy, TexIx.xy, TexIy.xy).rg;
                float2 W = tex2Dgrad(SampleI0, EW.zw, TexIx.xy, TexIy.xy).rg;
                float2 Ix = E - W;
                float2 Iy = N - S;

                // Get temporal gradient
                float4 TexIT = Tex.xyzw * PixelSize.xyxy;
                float2 I0 = tex2Dgrad(SampleI0, TexIT.xy, TexIx.xy, TexIy.xy).rg;
                float2 I1 = tex2Dgrad(SampleI1, TexIT.zw, TexIx.zw, TexIy.zw).rg;
                float2 IT = I0 - I1;

                // IxIx = A11; IyIy = A22; IxIy = A12/A22
                IxIx += dot(Ix, Ix);
                IyIy += dot(Iy, Iy);
                IxIy += dot(Ix, Iy);

                // IxIt = B1; IyIt = B2
                IxIt += dot(Ix, IT);
                IyIt += dot(Iy, IT);
            }
        }

        /*
            Calculate Lucas-Kanade matrix
            ---
            [ Ix^2/D -IxIy/D] [-IxIt]
            [-IxIy/D  Iy^2/D] [-IyIt]
        */

        // Calculate A^-1 and B
        float D = determinant(float2x2(IxIx, IxIy, IxIy, IyIy));
        float2x2 A = float2x2(IyIy, -IxIy, -IxIy, IxIx) / D;
        float2 B = float2(-IxIt, -IyIt);

        // Calculate A^T*B
        float2 Flow = (D == 0.0) ? 0.0 : mul(B, A);

        // Propagate and encode vectors
        return EncodeVectors(Vectors + Flow, PixelSize);
    }

    /*
        Modified version of VPlus' motion search algorithm
        ---
        https://github.com/bodhid/Vplus
        ---
        MIT License

        Copyright (c) 2018 Bodhi Donselaar

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    */

    struct Block
    {
        float4 Tex;
        float4 TexIx;
        float4 TexIy;
        float2 PixelSize;
    };

    void SampleBlock(in sampler2D Source, in float2 Tex, in float2 Ix, in float2 Iy, in float2 PixelSize, out float2 Pixel[4])
    {
        float4 HalfPixel = (Tex.xxyy + float4(-0.5, 0.5, -0.5, 0.5)) * PixelSize.xxyy;
        Pixel[0] = tex2Dgrad(Source, HalfPixel.xz, Ix, Iy).xy;
        Pixel[1] = tex2Dgrad(Source, HalfPixel.xw, Ix, Iy).xy;
        Pixel[2] = tex2Dgrad(Source, HalfPixel.yz, Ix, Iy).xy;
        Pixel[3] = tex2Dgrad(Source, HalfPixel.yw, Ix, Iy).xy;
    }

    float GetSAD(float2 Template[4], float2 Image[4])
    {
        float2 SAD = 0.0;
        for(int i = 0; i < 4; i++)
        {
            SAD += abs(Template[i] - Image[i]);
        }
        return max(SAD[0], SAD[1]);
    }

    float2 SearchArea(sampler2D SampleImage, Block B, float2 Template[4])
    {
        // Get constants
        const float Pi2 = acos(-1.0) * 2.0;

        // Initialize values
        float2 Vectors = 0.0;
        float2 Image[4];
        SampleBlock(SampleImage, B.Tex.zw, B.TexIx.zw, B.TexIy.zw, B.PixelSize, Image);
        float Minimum = GetSAD(Template, Image);

        [loop] for(int i = 1; i < 4; ++i)
        {
            [loop] for(int j = 0; j < 4 * i; ++j)
            {
                float Shift = (Pi2 / (4.0 * float(i))) * float(j);
                float2 AngleShift = 0.0;
                sincos(Shift, AngleShift.x, AngleShift.y);
                AngleShift *= float(i);

                SampleBlock(SampleImage, B.Tex.zw + AngleShift, B.TexIx.zw, B.TexIy.zw, B.PixelSize, Image);
                float SAD = GetSAD(Template, Image);
                Vectors = (SAD < Minimum) ? AngleShift : Vectors;
                Minimum = min(SAD, Minimum);
            }
        }

        return Vectors;
    }

    float2 GetPixelMFlow
    (
        float2 MainTex,
        float2 Vectors,
        sampler2D SampleTemplate,
        sampler2D SampleImage,
        int Level
    )
    {
        // Initialize data
        Block B;

        // Calculate main texel data (TexelSize, TexelLOD)
        B.Tex = float4(MainTex, MainTex + Vectors);
        B.TexIx = ddx(B.Tex);
        B.TexIy = ddy(B.Tex);
        B.PixelSize = abs(B.TexIx.xy) + abs(B.TexIy.xy);

        // Un-normalize data for processing
        B.Tex *= (1.0 / B.PixelSize.xyxy);
        Vectors = DecodeVectors(Vectors, B.PixelSize);

        // Pre-calculate template
        float2 Template[4];
        SampleBlock(SampleTemplate, B.Tex.xy, B.TexIx.xy, B.TexIy.xy, B.PixelSize, Template);

        // Calculate three-step search
        // Propagate and encode vectors
        Vectors += SearchArea(SampleImage, B, Template);
        return EncodeVectors(Vectors, B.PixelSize);
    }
#endif
