
# CShade

## About

CShade is an HLSL shader collection for ReShade. CShade introduces conventional image and video processing effects from a different angle.

CShade also includes `.fxh` files that contain algorithms used in the collection or have potential use.

## Important Note 

CShade shaders have markers that signify important notes about the shader.

* [D] **Depth Buffer**: Needs depth access.
* [&] **Linked**: Needs another shader enabled first.
* [+] **Preprocessor**: Extra features via **`Preprocessor definitions`**.
* [!] **Caution**: Major limitations or breaking changes.
* [?] **Info**: General notes or tips.
* [$] **Expensive**: High performance demand.

For example, if you see `CShade / Extremely Expensive Shader [D] [!]`, it means this shader requires access to the depth buffer and has critical limitations. The included markers provide quick reference to these specific requirements and cautions.

## Features

### Inter-Shader Merging

CShade allows users to blend shaders together and configure shaders to output a combination of Red/Green/Blue/Alpha.

### Adaptive Exposure

CShade features an adaptive-exposure shader that uses hardware blending for temporal smoothing. The shader also features spot-metering, allowing users to expose their image depending on an area.

### Image Processing

CShade features shaders that deal with getting information about an image.

- [AMD FidelityFX](https://gpuopen.com/amd-fidelityfx-sdk/)
    - [FidelityFX Lens](https://gpuopen.com/manuals/fidelityfx_sdk/fidelityfx_sdk-page_techniques_lens/)
    - [FidelityFX Contrast Adaptive Sharpening (CAS)](https://gpuopen.com/manuals/fidelityfx_sdk/fidelityfx_sdk-page_techniques_contrast-adaptive-sharpening/)
    - [FidelityFX Robust Contrast Adaptive Sharpening (RCAS)](https://gpuopen.com/manuals/fidelityfx_sdk/fidelityfx_sdk-page_techniques_super-resolution-upscaler/#robust-contrast-adaptive-sharpening-rcas)
- **Anti-aliasing**: [Fast Approximate Anti-Aliasing (FXAA)](https://en.wikipedia.org/wiki/Fast_approximate_anti-aliasing), [Directionally Localized Anti-Aliasing (DLAA)](http://www.and.intercon.ru/releases/talks/dlaagdc2011/)
- **Color conversions**: Chromaticity Spaces, Cylindrical Color Spaces, Polar Color Spaces, Grayscale
- **Convolutions**: Gaussian Blur, Edge Detection, Hierarchical (Joint) Bilateral Upsampling
- **Local normalization**: Census Transform, Local Contrast Normalization

### Video Processing

CShade features real-time motion estimation and feature-matching shaders through hierarchal Lucas-Kanade optical flow.

- Auto exposure
- Datamoshing
- Motion blur
- Motion stabilization
- Vector lines

### Post Processing

CShade features shaders that filter images for aesthetics.

- Backbuffer blending
- Dual-Kawase bloom
- Lens effect
- Letterbox
- Sharpening
- Vignetting

### AI-Assisted Programming with Gemini CLI

This project supports AI-assisted programming through the Gemini CLI. The Gemini CLI is an interactive command-line interface that leverages large language models to help with various software engineering tasks, including bug fixes, feature additions, refactoring, and code explanations.

#### How to Use

1.  **Install Gemini CLI**: Follow the [Gemini CLI installation instructions](https://www.geminicli.cc/docs/installation).
2.  **Navigate to Project Root**: Open your terminal or command prompt and navigate to the root directory of the CShade project:

    ```bash
    cd C:\Users\papadanku\Documents\GitHub\CShade
    ```

3.  **Start Gemini CLI**: Launch the Gemini CLI.
4.  **Interact with the AI**: You can now interact with the AI to get assistance with CShade. Here are some examples of what you can ask:

    - "Explain the `cMotionBlur.fx` shader."
    - "Refactor the `PS_DaltonizeFXmain` function in `Daltonize.fx` to use a more concise matrix multiplication for color conversion."
    - "Add a new uniform variable to `cLens.fx` that controls the chromatic aberration strength."
    - "Find all occurrences of `tex2Dlod` in the `shaders` directory."

For more detailed information on Gemini CLI capabilities and usage, refer to the `GEMINI.md` file in CShade's directory.

## Acknowledgments

### Groups

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

### Individuals

#### The Shadersphere

- BeTa/Alea
- BlueSkyDefender
- Pfoiffee
- Certain individuals in #code-chat/#shader-programming

#### GitHub Contributors

- **Overall:** 0CCULTIST
- **Reported Bugs:** Jakey757, simonedibilio, WardedPredator
- **Submitted Ideas:** mrjoshisattvablack, liuxd17thu, Maximus961
- **Asked Questions:** R0nBurgandy, lapsio

# Advanced Documentation

## Coding Convention

### UI

In `ui_category`/`ui_label`, use `·` to separate between subcategories, if needed

```md
uniform float _Level1Weight <
    ui_category = "Bloom · Level Weights";
    ui_label = "Level 1";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

uniform float _CShadeExposureSmoothingSpeed <
    ui_category = "Pipeline · Output · Auto Exposure";
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

### Virtual-Key Codes

> **See also:** https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

Constant | Value | Description
-------- | ----- | -----------
VK_LBUTTON | 0x01 | Left mouse button
VK_RBUTTON | 0x02 | Right mouse button
VK_CANCEL | 0x03 | Control-break processing
VK_MBUTTON | 0x04 | Middle mouse button
VK_XBUTTON1 | 0x05 | X1 mouse button
VK_XBUTTON2 | 0x06 | X2 mouse button
0x07 | Reserved
VK_BACK | 0x08 | Backspace key
VK_TAB | 0x09 | Tab key
0x0A-0B | Reserved
VK_CLEAR | 0x0C | Clear key
VK_RETURN | 0x0D | Enter key
0x0E-0F | Unassigned
VK_SHIFT | 0x10 | Shift key
VK_CONTROL | 0x11 | Ctrl key
VK_MENU | 0x12 | Alt key
VK_PAUSE | 0x13 | Pause key
VK_CAPITAL | 0x14 | Caps lock key
VK_KANA | 0x15 | IME Kana mode
VK_HANGUL | 0x15 | IME Hangul mode
VK_IME_ON | 0x16 | IME On
VK_JUNJA | 0x17 | IME Junja mode
VK_FINAL | 0x18 | IME final mode
VK_HANJA | 0x19 | IME Hanja mode
VK_KANJI | 0x19 | IME Kanji mode
VK_IME_OFF | 0x1A | IME Off
VK_ESCAPE | 0x1B | Esc key
VK_CONVERT | 0x1C | IME convert
VK_NONCONVERT | 0x1D | IME nonconvert
VK_ACCEPT | 0x1E | IME accept
VK_MODECHANGE | 0x1F | IME mode change request
VK_SPACE | 0x20 | Spacebar key
VK_PRIOR | 0x21 | Page up key
VK_NEXT | 0x22 | Page down key
VK_END | 0x23 | End key
VK_HOME | 0x24 | Home key
VK_LEFT | 0x25 | Left arrow key
VK_UP | 0x26 | Up arrow key
VK_RIGHT | 0x27 | Right arrow key
VK_DOWN | 0x28 | Down arrow key
VK_SELECT | 0x29 | Select key
VK_PRINT | 0x2A | Print key
VK_EXECUTE | 0x2B | Execute key
VK_SNAPSHOT | 0x2C | Print screen key
VK_INSERT | 0x2D | Insert key
VK_DELETE | 0x2E | Delete key
VK_HELP | 0x2F | Help key
`0` | 0x30 | 0 key
`1` | 0x31 | 1 key
`2` | 0x32 | 2 key
`3` | 0x33 | 3 key
`4` | 0x34 | 4 key
`5` | 0x35 | 5 key
`6` | 0x36 | 6 key
`7` | 0x37 | 7 key
`8` | 0x38 | 8 key
`9` | 0x39 | 9 key
0x3A-40 | Undefined
`A` | 0x41 | A key
`B` | 0x42 | B key
`C` | 0x43 | C key
`D` | 0x44 | D key
`E` | 0x45 | E key
`F` | 0x46 | F key
`G` | 0x47 | G key
`H` | 0x48 | H key
`I` | 0x49 | I key
`J` | 0x4A | J key
`K` | 0x4B | K key
`L` | 0x4C | L key
`M` | 0x4D | M key
`N` | 0x4E | N key
`O` | 0x4F | O key
`P` | 0x50 | P key
`Q` | 0x51 | Q key
`R` | 0x52 | R key
`S` | 0x53 | S key
`T` | 0x54 | T key
`U` | 0x55 | U key
`V` | 0x56 | V key
`W` | 0x57 | W key
`X` | 0x58 | X key
`Y` | 0x59 | Y key
`Z` | 0x5A | Z key
VK_LWIN | 0x5B | Left Windows logo key
VK_RWIN | 0x5C | Right Windows logo key
VK_APPS | 0x5D | Application key
0x5E | Reserved
VK_SLEEP | 0x5F | Computer Sleep key
VK_NUMPAD0 | 0x60 | Numeric keypad 0 key
VK_NUMPAD1 | 0x61 | Numeric keypad 1 key
VK_NUMPAD2 | 0x62 | Numeric keypad 2 key
VK_NUMPAD3 | 0x63 | Numeric keypad 3 key
VK_NUMPAD4 | 0x64 | Numeric keypad 4 key
VK_NUMPAD5 | 0x65 | Numeric keypad 5 key
VK_NUMPAD6 | 0x66 | Numeric keypad 6 key
VK_NUMPAD7 | 0x67 | Numeric keypad 7 key
VK_NUMPAD8 | 0x68 | Numeric keypad 8 key
VK_NUMPAD9 | 0x69 | Numeric keypad 9 key
VK_MULTIPLY | 0x6A | Multiply key
VK_ADD | 0x6B | Add key
VK_SEPARATOR | 0x6C | Separator key
VK_SUBTRACT | 0x6D | Subtract key
VK_DECIMAL | 0x6E | Decimal key
VK_DIVIDE | 0x6F | Divide key
VK_F1 | 0x70 | F1 key
VK_F2 | 0x71 | F2 key
VK_F3 | 0x72 | F3 key
VK_F4 | 0x73 | F4 key
VK_F5 | 0x74 | F5 key
VK_F6 | 0x75 | F6 key
VK_F7 | 0x76 | F7 key
VK_F8 | 0x77 | F8 key
VK_F9 | 0x78 | F9 key
VK_F10 | 0x79 | F10 key
VK_F11 | 0x7A | F11 key
VK_F12 | 0x7B | F12 key
VK_F13 | 0x7C | F13 key
VK_F14 | 0x7D | F14 key
VK_F15 | 0x7E | F15 key
VK_F16 | 0x7F | F16 key
VK_F17 | 0x80 | F17 key
VK_F18 | 0x81 | F18 key
VK_F19 | 0x82 | F19 key
VK_F20 | 0x83 | F20 key
VK_F21 | 0x84 | F21 key
VK_F22 | 0x85 | F22 key
VK_F23 | 0x86 | F23 key
VK_F24 | 0x87 | F24 key
0x88-8F | Reserved
VK_NUMLOCK | 0x90 | Num lock key
VK_SCROLL | 0x91 | Scroll lock key
0x92-96 | OEM specific
0x97-9F | Unassigned
VK_LSHIFT | 0xA0 | Left Shift key
VK_RSHIFT | 0xA1 | Right Shift key
VK_LCONTROL | 0xA2 | Left Ctrl key
VK_RCONTROL | 0xA3 | Right Ctrl key
VK_LMENU | 0xA4 | Left Alt key
VK_RMENU | 0xA5 | Right Alt key
VK_BROWSER_BACK | 0xA6 | Browser Back key
VK_BROWSER_FORWARD | 0xA7 | Browser Forward key
VK_BROWSER_REFRESH | 0xA8 | Browser Refresh key
VK_BROWSER_STOP | 0xA9 | Browser Stop key
VK_BROWSER_SEARCH | 0xAA | Browser Search key
VK_BROWSER_FAVORITES | 0xAB | Browser Favorites key
VK_BROWSER_HOME | 0xAC | Browser Start and Home key
VK_VOLUME_MUTE | 0xAD | Volume Mute key
VK_VOLUME_DOWN | 0xAE | Volume Down key
VK_VOLUME_UP | 0xAF | Volume Up key
VK_MEDIA_NEXT_TRACK | 0xB0 | Next Track key
VK_MEDIA_PREV_TRACK | 0xB1 | Previous Track key
VK_MEDIA_STOP | 0xB2 | Stop Media key
VK_MEDIA_PLAY_PAUSE | 0xB3 | Play/Pause Media key
VK_LAUNCH_MAIL | 0xB4 | Start Mail key
VK_LAUNCH_MEDIA_SELECT | 0xB5 | Select Media key
VK_LAUNCH_APP1 | 0xB6 | Start Application 1 key
VK_LAUNCH_APP2 | 0xB7 | Start Application 2 key
0xB8-B9 | Reserved
VK_OEM_1 | 0xBA | It can vary by keyboard. For the US ANSI keyboard , the Semiсolon and Colon key
VK_OEM_PLUS | 0xBB | For any country/region, the Equals and Plus key
VK_OEM_COMMA | 0xBC | For any country/region, the Comma and Less Than key
VK_OEM_MINUS | 0xBD | For any country/region, the Dash and Underscore key
VK_OEM_PERIOD | 0xBE | For any country/region, the Period and Greater Than key
VK_OEM_2 | 0xBF | It can vary by keyboard. For the US ANSI keyboard, the Forward Slash and Question Mark key
VK_OEM_3 | 0xC0 | It can vary by keyboard. For the US ANSI keyboard, the Grave Accent and Tilde key
0xC1-DA | Reserved
VK_OEM_4 | 0xDB | It can vary by keyboard. For the US ANSI keyboard, the Left Brace key
VK_OEM_5 | 0xDC | It can vary by keyboard. For the US ANSI keyboard, the Backslash and Pipe key
VK_OEM_6 | 0xDD | It can vary by keyboard. For the US ANSI keyboard, the Right Brace key
VK_OEM_7 | 0xDE | It can vary by keyboard. For the US ANSI keyboard, the Apostrophe and Double Quotation Mark key
VK_OEM_8 | 0xDF | It can vary by keyboard. For the Canadian CSA keyboard, the Right Ctrl key
0xE0 | Reserved
0xE1 | OEM specific
VK_OEM_102 | 0xE2 | It can vary by keyboard. For the European ISO keyboard, the Backslash and Pipe key
0xE3-E4 | OEM specific
VK_PROCESSKEY | 0xE5 | IME PROCESS key
0xE6 | OEM specific
VK_PACKET | 0xE7 | Used to pass Unicode characters as if they were keystrokes. The VK_PACKET key is the low word of a 32-bit Virtual Key value used for non-keyboard input methods. For more information, see Remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
0xE8 | Unassigned
0xE9-F5 | OEM specific
VK_ATTN | 0xF6 | Attn key
VK_CRSEL | 0xF7 | CrSel key
VK_EXSEL | 0xF8 | ExSel key
VK_EREOF | 0xF9 | Erase EOF key
VK_PLAY | 0xFA | Play key
VK_ZOOM | 0xFB | Zoom key
VK_NONAME | 0xFC | Reserved
VK_PA1 | 0xFD | PA1 key
VK_OEM_CLEAR | 0xFE | Clear key
