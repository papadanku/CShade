
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

### UI

- In `ui_category`/`ui_label`, use `|` to separate between subcategories, if needed

  ```md
  uniform float _Level1Weight <
      ui_category = "Bloom | Level Weights";
      ui_label = "Level 1";
      ui_type = "slider";
      ui_min = 0.0;
      ui_max = 1.0;
  > = 1.0;
  ```

- In uniforms stored in `.fxh` header files, wrap `[ ]` around `ui_category`/`ui_label`

  ```md
  uniform float _CShadeExposureSmoothingSpeed <
      ui_category = "[ Pipeline | Output | AutoExposure ]";
      ui_label = "Smoothing Speed";
      ui_type = "slider";
      ui_min = 0.1;
      ui_max = 1.0;
  > = 0.25;
  ```

### Functions and Variables

#### Shared Method From Header File

  `shared/common/cLib.fxh` -> `Common_CLib_FunctionName()`

#### ALLCAPS

- State parameters

  `BlendOp = ADD`

- System semantics

  `float4 SV_POSITION`

#### ALL_CAPS

- Preprocessor definition

  `#define SHADER_VERSION`

- Preprocessor Macros

  `#define EXAMPLE_MACRO()`

- Preprocessor Macro Arguments

  `#define EXAMPLE_MACRO(EXAMPLE_ARG)`

#### _SnakeCase

- Uniform variables

  `uniform float3 _Example`

#### SnakeCase

- Function arguments

  `void Function(float4 ArgumentOne)`

- Global Variables

  ```md
  static const float4 GlobalVariable = 1.0;
  void Function()
  {
      return GlobalVariable;
  }
  ```

- Local Variables

  ```md
  void Function()
  {
      float4 LocalVariable = 1.0;
      return LocalVariable;
  }
  ```

- Textures and Samples

  `texture2D ExampleTex ...`

  `sampler2D SampleExampleTex ...`

#### SNAKE_Case

- `struct` datatype

  `struct APP2VS_Example ...`

  `struct VS2PS_Example ...`

  `struct PS2FB_Example ...`

  `struct PS2MRT_Example ...`

- `VertexShader` and `PixelShader`

  `VertexShader = VS_Example;`

  `PixelShader = PS_Example;`

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
