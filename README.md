
# CShade

## About

CShade is an HLSL shader collection for ReShade. CShade introduces conventional image and video processing effects from a different angle.

CShade also includes `.fxh` files that contain algorithms used in the collection.

## Effects

### Adaptive Exposure

CShade features an adaptive-exposure shader that uses hardware blending for temporal smoothing. The shader also features spot-metering, allowing users to expose their image depending on an area.

### Color Processing

CShade features shaders that deal with getting information about RGB images.

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

Practice | Elements
-------- | --------
**ALLCAPS** | System semantics • State parameters
**ALL_CAPS** | Preprocessor (macros & arguments)
**_SnakeCase** | Variables (uniform)
**SnakeCase** | Variables (local & global) • Method arguments
**Snake_Case** | Data subcatagory
**PREFIX_Data** | `struct` • `PixelShader` • `VertexShader`
