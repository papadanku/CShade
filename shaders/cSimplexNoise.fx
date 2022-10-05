
uniform float Time < source = "timer"; >;

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

/*
    Copyright (C) 2011 by Ashima Arts (Simplex noise)
    Copyright (C) 2011-2016 by Stefan Gustavson (Classic noise and others)

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

float2 Mod_289(float2 X)
{
    return X - floor(X * (1.0 / 289.0)) * 289.0;
}

float3 Mod_289(float3 X)
{
    return X - floor(X * (1.0 / 289.0)) * 289.0;
}

float4 Mod_289(float4 X)
{
    return X - floor(X * (1.0 / 289.0)) * 289.0;
}

float2 Permute(float2 X)
{
    return Mod_289(((X * 34.0) + 10.0)* X);
}

float4 Permute(float4 X)
{
    return Mod_289(((X * 34.0) + 10.0) * X);
}

float4 Taylor_Inverse_Sqrt(float4 r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}

float Simplex_Noise(float3 V)
{
    const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
    const float4 D = float4(0.0, 0.5, 1.0, 2.0);

    // First corner
    float3 I = floor(V + dot(V, C.yyy));
    float3 X0 = V - I + dot(I, C.xxx);

    // Other corners
    float3 G = step(X0.yzx, X0.xyz);
    float3 L = 1.0 - G;
    float3 I1 = min(G.xyz, L.zxy);
    float3 I2 = max(G.xyz, L.zxy);

    // X0 = X0 - 0.0 + 0.0 * C.xxx;
    // X1 = X0 - I1  + 1.0 * C.xxx;
    // X2 = X0 - I2  + 2.0 * C.xxx;
    // X3 = X0 - 1.0 + 3.0 * C.xxx;
    float3 X1 = X0 - I1 + C.xxx;
    float3 X2 = X0 - I2 + C.yyy; // 2.0 * C.x = 1/3 = C.y
    float3 X3 = X0 - D.yyy; // -1.0 + 3.0 * C.x = -0.5 = -D.y

    // Permutations
    I = Mod_289(I); 
    float4 P = Permute(Permute(Permute(I.z + float4(0.0, I1.z, I2.z, 1.0))
                                     + I.y + float4(0.0, I1.y, I2.y, 1.0)) 
                                     + I.x + float4(0.0, I1.x, I2.x, 1.0));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49 * 6 = 294)
    float N = 0.142857142857; // 1.0 / 7.0
    float3 NS = N * D.wyz - D.xzx;

    float4 J = P - 49.0 * floor(P * NS.z * NS.z); // mod(P, 7 * 7)

    float4 X_ = floor(J * NS.z);
    float4 Y_ = floor(J - 7.0 * X_); // mod(J, N)

    float4 X = X_ * NS.x + NS.yyyy;
    float4 Y = Y_ * NS.x + NS.yyyy;
    float4 H = 1.0 - abs(X) - abs(Y);

    float4 B0 = float4(X.xy, Y.xy);
    float4 B1 = float4(X.zw, Y.zw);

    // float4 S0 = float4(lessThan(B0, 0.0)) * 2.0 - 1.0;
    // float4 S1 = float4(lessThan(B1, 0.0)) * 2.0 - 1.0;
    float4 S0 = floor(B0) * 2.0 + 1.0;
    float4 S1 = floor(B1) * 2.0 + 1.0;
    float4 Sh = -step(H, 0.0);

    float4 A0 = B0.xzyw + S0.xzyw * Sh.xxyy;
    float4 A1 = B1.xzyw + S1.xzyw * Sh.zzww;

    float3 P0 = float3(A0.xy, H.x);
    float3 P1 = float3(A0.zw, H.y);
    float3 P2 = float3(A1.xy, H.z);
    float3 P3 = float3(A1.zw, H.w);

    //Normalise gradients
    float4 Norm = Taylor_Inverse_Sqrt(float4(dot(P0, P0), dot(P1, P1), dot(P2, P2), dot(P3, P3)));
    P0 *= Norm.x;
    P1 *= Norm.y;
    P2 *= Norm.z;
    P3 *= Norm.w;

    // Mix final noise value
    float4 M = max(0.5 - float4(dot(X0,X0), dot(X1,X1), dot(X2,X2), dot(X3,X3)), 0.0);
    M = M * M;
    return 105.0 * dot(M * M, float4(dot(P0, X0), dot(P1, X1), dot(P2, X2), dot(P3, X3)));
}

void Simplex_Noise_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float3 Value_3 = float3(Position.xy / 2.0, Time / min(BUFFER_WIDTH, BUFFER_HEIGHT));
    OutputColor0 = Simplex_Noise(Value_3) * 0.5 + 0.5;
}

technique cSimplexNoise
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Simplex_Noise_PS;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = ONE;
        DestBlend = ONE;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
