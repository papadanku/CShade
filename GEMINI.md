# Gemini Project Guide: CShade

This `GEMINI.md` file serves as a comprehensive guide for AI agents interacting with the CShade project. It outlines the project's purpose, how to use its components, and established development conventions.

## Project Overview

CShade is a collection of High-Level Shading Language (HLSL) shaders designed for use with ReShade, a generic post-processing injector for games and video software. The project's primary goal is to provide a wide array of image, video, and post-processing effects, approaching them from a unique perspective.

**Key Features:**

*   **Inter-Shader Merging:** Allows blending multiple shaders and configuring individual color channel outputs (Red, Green, Blue, Alpha).
*   **Adaptive Exposure:** Includes an adaptive-exposure shader with hardware blending for temporal smoothing and spot-metering capabilities.
*   **Diverse Processing Effects:** Encompasses various effects for image processing (e.g., sharpening like CAS/RCAS, anti-aliasing like FXAA/DLAA, color conversions, convolutions), video processing (e.g., optical flow, datamoshing, motion blur, motion stabilization), and aesthetic post-processing (e.g., bloom, color grading, lens effects).
*   **Modular Design:** Utilizes `.fxh` (include) files for shared algorithms and functions, promoting code reusability.

The project is primarily composed of `.fx` shader files and `.fxh` include files, written in HLSL for the ReShade framework.

## Usage with ReShade

CShade shaders are designed to be integrated directly into the ReShade post-processing pipeline. There isn't a traditional "build" process for these shaders; instead, they are placed in the appropriate ReShade shaders directory.

**General Steps for Using CShade Shaders:**

1.  **Install ReShade:** Ensure ReShade is correctly installed and configured for your target application.
2.  **Place Shaders:** Copy the `.fx` and `.fxh` files from the `shaders/` directory (and its subdirectories) of this project into your ReShade shaders folder (e.g., `ReShade-shaders/Shaders/`). Ensure the `shared/` subdirectory structure is maintained.
3.  **Enable in ReShade UI:** Launch your application with ReShade, open the ReShade in-game overlay, and select the desired CShade `.fx` shaders from the list to enable them.
4.  **Configure Shaders:** Adjust the shader settings via the ReShade UI. Pay attention to UI markers (`[D]`, `[&]`, `[+]`, `[!]`, `[?]`, `[$]`) which provide important notes, requirements (like depth buffer access), or performance considerations.

## Development Conventions

The following coding conventions are observed within the CShade project, particularly for HLSL shader development:

### UI Parameters

For `ui_category` and `ui_label` annotations in uniform variables, use a forward slash `/` to delineate subcategories.

**Example:**

```hlsl
uniform float _Level1Weight <
    ui_category = "Bloom / Level Weights";
    ui_label = "Level 1";
    // ... other UI properties
> = 1.0;
```

### Naming Conventions for Functions and Variables

*   **Shared Methods from Header Files (`.fxh`):**
    Functions imported from shared header files follow the pattern `ModuleName_FunctionName()`.
    *Example:* `shared/common/cLib.fxh` would contain functions like `Common_CLib_FunctionName()`.

*   **ALLCAPS:**
    *   State parameters (e.g., `BlendOp = ADD;`)
    *   System semantics (e.g., `float4 SV_POSITION;`)

*   **ALL_CAPS:**
    *   Preprocessor definitions (e.g., `#define SHADER_VERSION`)
    *   Preprocessor macros (e.g., `#define EXAMPLE_MACRO()`)
    *   Preprocessor macro arguments (e.g., `#define EXAMPLE_MACRO(EXAMPLE_ARG)`)

*   **_SnakeCase:**
    *   Uniform variables (e.g., `uniform float3 _Example;`)

*   **SnakeCase:**
    *   Function arguments (e.g., `void Function(float4 ArgumentOne);`)
    *   Global variables (e.g., `static const float4 GlobalVariable = 1.0;`)
    *   Local variables (e.g., `float4 LocalVariable = 1.0;`)
    *   Textures and Samplers (e.g., `texture2D ExampleTex;`, `sampler2D SampleExampleTex;`)

*   **SNAKE_Case:**
    *   `struct` data types (e.g., `struct APP2VS_Example;`, `struct VS2PS_Example;`, `struct PS2FB_Example;`, `struct PS2MRT_Example;`)
    *   `VertexShader` and `PixelShader` entry points (e.g., `VertexShader = VS_Example;`, `PixelShader = PS_Example;`)

## AI-Assisted Programming with Gemini CLI

This project is configured for AI-assisted programming using the Gemini CLI. A specialized skill for ReShadeFX is available within the `.gemini/skills/reshadefx` directory. This skill provides expert guidance and workflows for developing and debugging ReShadeFX shaders.

**To leverage AI assistance:**

1.  Ensure the Gemini CLI is installed and configured.
2.  Navigate to the root directory of this project in your terminal.
3.  Activate the `reshadefx` skill when working on ReShadeFX-related tasks.
4.  Interact with the AI to perform tasks such as explaining shaders, refactoring code, adding features, or debugging.
