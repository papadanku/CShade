
# CShade

## About

CShade is an HLSL shader collection for ReShade. CShade introduces conventional image and video processing effects from a different angle.

CShade also includes `.fxh` files that contain algorithms used in the collection.

## Effects

### Adaptive Exposure

CShade features an adaptive-exposure shader that uses hardware blending for temporal smoothing. The shader also features spot-metering, allowing users to expose their image depending on an area.

### Image Processing

CShade features shaders that deal with getting information about an image.

- Census transformation
- Convolutions
- Chromaticity
- Edge-detection
- Grayscale

### Video Processing

CShade features real-time motion estimation and feature-matching shaders.

- Hierarchal block-matching
- Lucas-Kanade optical flow
- Template-matching

### Post Processing

CShade features shaders that filter images for aesthetics.

- Backbuffer blending
- Dual-Kawase bloom
- Film-grain
- Sharpening
- Vignetting

## Coding Convention

- Prefix shared method with it's file name.
    - `shared/common/cLib.fxh` -> `Common_CLib_FunctionName()`
- **ALLCAPS**
    - State parameters
    - System semantics
- **ALL_CAPS**
    - Preprocessor Macros
    - Preprocessor Macro Arguments
- **_SnakeCase**
    - Uniform variables
- **SnakeCase**
    - Function arguments
    - Global Variables
    - Local Variables
    - Textures and Samples
- **Snake_Case**
    - Data subcategory
- **PREFIX_Data**
    - `struct` datatype

        `APP2VS_`

        `VS2PS_`

        `PS2FB_`

        `PS2MRT_`

    - `VertexShader` methods

        `VS_`

    - `PixelShader` methods

        `PS_`

## Acknowledgments

- [The Forgotten Hope Team](http://forgottenhope.warumdarum.de/)

    Major knowledge-base and inspiration.

- [The Project Reality Team](https://www.realitymod.com/)

    memes

- [The ReShade Community](https://reshade.me/)

    Where the coding journey started.

- [Vietnamese Student Association](https://www.instagram.com/asu.vsa)

    The community I needed.

- Family, friends, and acquaintances

    You know who you are.
