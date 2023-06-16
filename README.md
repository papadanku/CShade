
# CShade

## About

CShade is an HLSL shader collection for ReShade. CShade's purpose is to introduce conventional image and video processing effects from a different angle.

CShade also includes `.fxh` files that contain common algorithms used in the collection.

## Effects

### Adaptive Exposure

CShade features an adaptive-exposure shader that uses hardware blending as for temporal smoothing. The shader also features spot-metering, allowing the user to expose their image depending on a certain area.

### Color Processing

CShade features various shaders that deal with getting certain information about RGB images.

- Census transformation
- Convolutions
- Chromaticity
- Edge-detection
- Grayscale

### Video Processing

CShade features real-time motion estimation and feature-matching algorithms.

- Hierarchal block-matching
- Lucas-Kanade optical flow
- Template-matching

### Post Processing

CShade features various shaders that deal with filtering images for aesthetics.

- Backbuffer blending
- Dual-Kawasae bloom
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
