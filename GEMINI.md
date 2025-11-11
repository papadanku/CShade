# CShade Project Overview

CShade is an HLSL shader collection designed for ReShade, focusing on advanced image and video processing effects. The project aims to provide a versatile set of shaders for post-processing, including adaptive exposure, various image enhancements (e.g., AMD FidelityFX, anti-aliasing, color conversions, convolutions), video processing (e.g., motion estimation, motion blur), and aesthetic post-processing effects (e.g., bloom, lens effects).

The codebase is structured with individual `.fx` files for specific shader effects and a `shared` directory containing `.fxh` header files. These header files encapsulate common algorithms, utility functions, and macros, promoting modularity and reusability across different shaders.

## Key Features

* **Inter-Shader Merging:** Allows blending multiple shaders and configuring output channels.
* **Adaptive Exposure:** Features hardware blending for temporal smoothing and spot-metering.
* **Image Processing:** Includes AMD FidelityFX techniques (CAS, RCAS, Lens), various anti-aliasing methods (FXAA, DLAA), color conversions, convolutions (Gaussian blur, edge detection), and local normalization.
* **Video Processing:** Incorporates real-time motion estimation and feature-matching through hierarchical Lucas-Kanade optical flow for effects like datamoshing, motion blur, and motion stabilization.
* **Post Processing:** Offers aesthetic filters such as backbuffer blending, Dual-Kawase bloom, lens effects, letterboxing, sharpening, and vignetting.

## Architecture and Conventions

The project follows a modular architecture where `.fx` files define specific shader passes and techniques, while `.fxh` files provide shared functionalities.

### Core Components:

* **`.fx` files:** Individual shader implementations (e.g., `cAutoExposure.fx`, `cBlurV.fx`).
* **`shared/.fxh` files:** Header files containing reusable code, including:
    * `cShade.fxh`: Defines core macros for UI elements, texture/sampler creation, and a common vertex shader for full-screen quads.
    * `cMath.fxh`: A comprehensive math library with functions for vector operations, matrix transformations, noise generation, normalization, and more.
    * `cBlur.fxh`: Contains various blur algorithms and related utility functions.
    * Other `.fxh` files for color, camera, composite operations, etc.

### Coding Conventions:

The `README.md` outlines detailed coding conventions, including:

* **UI Categories:** Uses `·` to separate subcategories in `ui_category` for ReShade's UI.
* **Naming Conventions:** Specific patterns for functions, variables (uniform, global, local), preprocessor directives, structs, textures, and samplers (e.g., `_SnakeCase` for uniform variables, `SNAKE_Case` for structs).
* **Virtual-Key Codes:** A comprehensive list of Windows virtual-key codes is provided for reference.

## Building and Running

This project consists of HLSL shader files designed to be used with **ReShade**. There are no traditional build steps (like compiling an executable) for the shaders themselves.

To "run" these shaders:

1. **Install ReShade:** Ensure ReShade is installed and configured for your target application or game.
2. **Place Shaders:** Copy the `.fx` and `shared/.fxh` files into your ReShade shaders folder (typically `ReShade-shaders\Shaders` or a custom path configured in ReShade).
3. **Configure in ReShade UI:** Launch your application with ReShade, open the ReShade in-game UI, and enable the desired CShade effects. Parameters for the shaders can be adjusted directly within the ReShade UI, as defined by the `ui_category`, `ui_label`, and `ui_type` annotations in the shader files.

## Development Conventions

* **Modularity:** Common functionalities are extracted into `.fxh` header files within the `shared` directory.
* **UI Integration:** Shaders are designed with ReShade's UI in mind, using `uniform` variables with specific `ui_` annotations for user-friendly parameter control.
* **Preprocessor Directives:** Extensively uses `#define` and `#if` directives for conditional compilation and feature toggling.
* **Mathematical Utilities:** Leverages a rich set of mathematical functions provided in `cMath.fxh` for complex calculations.
* **Texture and Sampler Management:** Utilizes custom macros (`CREATE_TEXTURE`, `CREATE_SAMPLER`, etc.) for consistent definition of textures and samplers.

@./gemini/Examples.txt
@./gemini/REFERENCE.md
@./gemini/ReShade.fxh
