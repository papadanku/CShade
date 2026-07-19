# CShade Agent Instructions

## Repo Type
ReShade HLSL shader collection. No build system, no tests. Only `.fx` (shaders) and `.fxh` (headers) files.

## Structure
- `shaders/` — Individual shader files (`.fx`)
- `shaders/shared/` — Reusable header files (`.fxh`) included via `#include`
- Root `README.md` — Authoritative source for coding conventions and UI markers

## File Types
- `.fx` — Complete ReShade shaders
- `.fxh` — HLSL header files for shared code

## Coding Conventions (from README.md)
- **UI labels/categories**: Use `/` for subcategories (e.g., `ui_category = "Bloom / Level Weights"`)
- **Naming**:
  - ALLCAPS: state parameters, system semantics
  - ALL_CAPS: preprocessor definitions and macros
  - _SnakeCase: uniform variables
  - SnakeCase: function args, global variables, local variables, textures, samplers
  - SNAKE_Case: structs, VertexShader, PixelShader

## Shader System
- Core utilities in `shaders/shared/cShade.fxh`
- Includes composite system, lens effects, blending
- Shaders include cShade.fxh with preprocessor defines to control features
- UI markers: `[D]` Depth Buffer, `[&]` Linked, `[+]` Preprocessor, `[!]` Caution, `[?]` Info, `[$]` Expensive

## Commands
None. This is a shader-only repo. No build, test, or lint steps.

## Verification
- Validate HLSL syntax by loading in ReShade
- Check includes resolve correctly
- Verify UI markers match shader capabilities
