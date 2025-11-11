
#include "cColor.fxh"

#if !defined(INCLUDE_CColor_OUTPUT)
    #define INCLUDE_CColor_OUTPUT

    #ifndef CCOMPOSITE_TOGGLE_GRADING
        #define CCOMPOSITE_TOGGLE_GRADING 1
    #endif

    #ifndef CCOMPOSITE_TOGGLE_TONEMAP
        #define CCOMPOSITE_TOGGLE_TONEMAP 1
    #endif

    #if CCOMPOSITE_TOGGLE_GRADING
        // Primary Adjustments
        uniform float _CComposite_ExposureBias <
            ui_category = "Pipeline / Output / Color Grade";
            ui_text = "Exposure & Color Filter";
            ui_label = "Exposure Bias (f-stops)";
            ui_type = "slider";
            ui_tooltip = "Adjusts the overall exposure of the scene in f-stops, making it brighter or darker.";
        > = 0.0;

        uniform float3 _CComposite_ColorFilter <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Color Filter (White Balance)";
            ui_type = "color";
            ui_tooltip = "Applies a color tint to the scene, useful for adjusting white balance or creating stylistic looks.";
        > = 1.0;

        uniform float _CComposite_Saturation <
            ui_category = "Pipeline / Output / Color Grade";
            ui_text = "\nSaturation & Contrast";
            ui_label = "Saturation";
            ui_type = "slider";
            ui_tooltip = "Adjusts the intensity of colors in the scene; higher values make colors more vibrant, lower values desaturate them.";
        > = 1.0;

        uniform float _CComposite_Contrast <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Contrast";
            ui_type = "slider";
            ui_tooltip = "Adjusts the difference between the brightest and darkest parts of the image, affecting perceived depth and richness.";
        > = 1.0;

        // Lift/Gamma/Gain - Color Controls
        uniform float3 _CComposite_ShadowColor <
            ui_category = "Pipeline / Output / Color Grade";
            ui_text = "\nLift/Gamma/Gain";
            ui_label = "Shadow Color (Lift)";
            ui_type = "color";
            ui_tooltip = "Adjusts the color tint applied to the darkest areas (shadows) of the image.";
        > = 1.0;

        uniform float3 _CComposite_MidtoneColor <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Midtone Color (Gamma)";
            ui_type = "color";
            ui_tooltip = "Adjusts the color tint applied to the mid-range tones (midtones) of the image.";
        > = 1.0;

        uniform float3 _CComposite_HighlightColor <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Highlight Color (Gain)";
            ui_type = "color";
            ui_tooltip = "Adjusts the color tint applied to the brightest areas (highlights) of the image.";
        > = 1.0;

        // Lift/Gamma/Gain - Offset Controls
        uniform float _CComposite_ShadowOffset <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Shadow Offset";
            ui_type = "slider";
            ui_tooltip = "Adjusts the offset for shadow values, making dark areas brighter or darker.";
        > = 0.0;

        uniform float _CComposite_MidtoneOffset <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Midtone Offset";
            ui_type = "slider";
            ui_tooltip = "Adjusts the offset for midtone values, affecting the brightness of mid-range tones.";
        > = 0.0;

        uniform float _CComposite_HighlightOffset <
            ui_category = "Pipeline / Output / Color Grade";
            ui_label = "Highlight Offset";
            ui_type = "slider";
            ui_tooltip = "Adjusts the offset for highlight values, making bright areas brighter or darker.";
        > = 0.0;
    #endif

    #if CCOMPOSITE_TOGGLE_GRADING || CCOMPOSITE_TOGGLE_TONEMAP
        uniform int _CComposite_Tonemapper <
            ui_category_closed = true;
            ui_category = "Pipeline / Output / Tonemap";
            ui_label = "Tonemap Operator";
            ui_tooltip = "Selects a tonemap operator to map HDR colors to SDR, affecting how bright areas are compressed.";
            ui_type = "combo";
            ui_items = "None\0Reinhard\0Reinhard Squared\0AMD Resolve\0Logarithmic C [Encode]\0";
        > = 2;
    #endif

    float3 CComposite_ApplyOutputTonemap(float3 HDR)
    {
        return CColor_ApplyTonemap(HDR, _CComposite_Tonemapper);
    }

    /*
        John Hable's Minimal Color Grading

        1. Exposure
        2. Color Filter
        3. Saturation
        4. Log-Space Contrast
        5. Filmic Tone Curve
        6. Display Gamma
        7. Lift/Gamma/Gain

        Creative Commons Legal Code

        CC0 1.0 Universal

            CREATIVE COMMONS CORPORATION IS NOT A LAW FIRM AND DOES NOT PROVIDE LEGAL SERVICES. DISTRIBUTION OF THIS DOCUMENT DOES NOT CREATE AN ATTORNEY-CLIENT RELATIONSHIP. CREATIVE COMMONS PROVIDES THIS INFORMATION ON AN "AS-IS" BASIS. CREATIVE COMMONS MAKES NO WARRANTIES REGARDING THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS PROVIDED HEREUNDER, AND DISCLAIMS LIABILITY FOR DAMAGES RESULTING FROM THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS PROVIDED HEREUNDER.

        Statement of Purpose

        The laws of most jurisdictions throughout the world automatically confer exclusive Copyright and Related Rights (defined below) upon the creator and subsequent owner(s) (each and all, an "owner") of an original work of authorship and/or a database (each, a "Work").

        Certain owners wish to permanently relinquish those rights to a Work for the purpose of contributing to a commons of creative, cultural and scientific works ("Commons") that the public can reliably and without fear of later claims of infringement build upon, modify, incorporate in other works, reuse and redistribute as freely as possible in any form whatsoever and for any purposes, including without limitation commercial purposes. These owners may contribute to the Commons to promote the ideal of a free culture and the further production of creative, cultural and scientific works, or to gain reputation or greater distribution for their Work in part through the use and efforts of others.

        For these and/or other purposes and motivations, and without any expectation of additional consideration or compensation, the person associating CC0 with a Work (the "Affirmer"), to the extent that he or she is an owner of Copyright and Related Rights in the Work, voluntarily elects to apply CC0 to the Work and publicly distribute the Work under its terms, with knowledge of his or her Copyright and Related Rights in the Work and the meaning and intended legal effect of CC0 on those rights.

        1. Copyright and Related Rights. A Work made available under CC0 may be protected by copyright and related or neighboring rights ("Copyright and Related Rights"). Copyright and Related Rights include, but are not limited to, the following:

            i. the right to reproduce, adapt, distribute, perform, display, communicate, and translate a Work;
            ii. moral rights retained by the original author(s) and/or performer(s);
            iii. publicity and privacy rights pertaining to a person's image or likeness depicted in a Work;
            iv. rights protecting against unfair competition in regards to a Work, subject to the limitations in paragraph 4(a), below;
            v. rights protecting the extraction, dissemination, use and reuse of data in a Work;
            vi. database rights (such as those arising under Directive 96/9/EC of the European Parliament and of the Council of 11 March 1996 on the legal protection of databases, and under any national implementation thereof, including any amended or successor version of suchdirective); and
            vii. other similar, equivalent or corresponding rights throughout the world based on applicable law or treaty, and any national implementations thereof.

        2. Waiver. To the greatest extent permitted by, but not in contravention of, applicable law, Affirmer hereby overtly, fully, permanently, irrevocably and unconditionally waives, abandons, and surrenders all of Affirmer's Copyright and Related Rights and associated claims and causes of action, whether now known or unknown (including existing as well as future claims and causes of action), in the Work (i) in all territories worldwide, (ii) for the maximum duration provided by applicable law or treaty (including future time extensions), (iii) in any current or future medium and for any number of copies, and (iv) for any purpose whatsoever, including without limitation commercial, advertising or promotional purposes (the "Waiver"). Affirmer makes the Waiver for the benefit of each member of the public at large and to the detriment of Affirmer's heirs and successors, fully intending that such Waiver shall not be subject to revocation, rescission, cancellation, termination, or any other legal or equitable action to disrupt the quiet enjoyment of the Work by the public as contemplated by Affirmer's express Statement of Purpose.

        3. Public License Fallback. Should any part of the Waiver for any reason be judged legally invalid or ineffective under applicable law, then the Waiver shall be preserved to the maximum extent permitted taking into account Affirmer's express Statement of Purpose. In addition, to the extent the Waiver is so judged Affirmer hereby grants to each affected person a royalty-free, non transferable, non sublicensable, non exclusive, irrevocable and unconditional license to exercise Affirmer's Copyright and Related Rights in the Work (i) in all territories worldwide, (ii) for the maximum duration provided by applicable law or treaty (including future time extensions), (iii) in any current or future medium and for any number of copies, and (iv) for any purpose whatsoever, including without limitation commercial, advertising or promotional purposes (the "License"). The License shall be deemed effective as of the date CC0 was applied by Affirmer to the Work. Should any part of the License for any reason be judged legally invalid or ineffective under applicable law, such partial invalidity or ineffectiveness shall not invalidate the remainder of the License, and in such case Affirmer hereby affirms that he or she will not (i) exercise any of his or her remaining Copyright and Related Rights in the Work or (ii) assert any associated claims and causes of action with respect to the Work, in either case contrary to Affirmer's express Statement of Purpose.

        4. Limitations and Disclaimers.

            a. No trademark or patent rights held by Affirmer are waived, abandoned, surrendered, licensed or otherwise affected by this document.
            b. Affirmer offers the Work as-is and makes no representations or warranties of any kind concerning the Work, express, implied, statutory or otherwise, including without limitation warranties of title, merchantability, fitness for a particular purpose, non infringement, or the absence of latent or other defects, accuracy, or the present or absence of errors, whether or not discoverable, all to the greatest extent permissible under applicable law.
            c. Affirmer disclaims responsibility for clearing rights of other persons that may apply to the Work or any use thereof, including without limitation any person's Copyright and Related Rights in the Work. Further, Affirmer disclaims responsibility for obtaining any necessary consents, permissions or other rights required for any use of the Work.
            d. Affirmer understands and acknowledges that Creative Commons is not a party to this document and has no duty or obligation with respect to this CC0 or use of the Work.
    */

    void CComposite_ApplyColorGrading(
        inout float3 Color,
        in float ExposureBias,
        in float3 ColorFilter,
        in float Saturation,
        in float Contrast,
        in float3 ShadowColor,
        in float3 MidtoneColor,
        in float3 HighlightColor,
        in float ShadowOffset,
        in float MidtoneOffset,
        in float HighlightOffset
    )
    {
        // Constants
        const float ACEScc_MIDGRAY = 0.4135884;

        // Create controls for Lift/Gamma/Gain
        float3 LiftC = ShadowColor;
        float3 GammaC = MidtoneColor;
        float3 GainC = HighlightColor;

        float AverageLift = dot(LiftC, 1.0 / 3.0);
        float AverageGamma = dot(GammaC, 1.0 / 3.0);
        float AverageGain = dot(GainC, 1.0 / 3.0);

        LiftC = LiftC - AverageLift;
        GammaC = GammaC - AverageGamma;
        GainC = GainC - AverageGain;

        float3 LiftAdjust = 0.0 + (LiftC + ShadowOffset);
        float3 GainAdjust = 1.0 + (GainC + HighlightOffset);

        float3 MidGrey = 0.5 + (GammaC + MidtoneOffset);
        float3 H = GainAdjust;
        float3 S = LiftAdjust;

        float3 GammaAdjust = log((0.5 - S) / (H - S)) / log(MidGrey);
        float3 InvGammaAdjust = 1.0 / GammaAdjust;

        // Exposure & Color Filter multiplier
        float3 ExposureColorFilter = exp2(ExposureBias) * ColorFilter;
        Color = Color * ExposureColorFilter;
        
        // Apply Saturation
        float Gray = CColor_RGBtoLuma(Color.rgb, 3);
        Color = Gray + Saturation * (Color - Gray);

        // Apply Log Contrast
        Color = CColor_EncodeLogC(Color);
        Color = (Color - ACEScc_MIDGRAY) * Contrast + ACEScc_MIDGRAY;
        Color = CColor_DecodeLogC(Color);
        Color = max(Color, 0.0);

        // Apply Filmic Curve
        Color = CColor_ApplyTonemap(Color, _CComposite_Tonemapper);

        // Apply Display Gamma
        Color = CColor_RGBtoSRGB(float4(Color, 0.0)).rgb;

        // Apply Lift-Gamma-Gain
        float3 Weight = pow(abs(Color), InvGammaAdjust);
        Color = lerp(LiftAdjust, GainAdjust, Weight);

        // Apply Linear Gamma
        Color = CColor_SRGBtoRGB(float4(Color, 0.0)).rgb;
    }

    void CComposite_ApplyOutput(inout float3 Color)
    {
        #if CCOMPOSITE_TOGGLE_GRADING
            CComposite_ApplyColorGrading(
                Color,
                _CComposite_ExposureBias,
                _CComposite_ColorFilter,
                _CComposite_Saturation,
                _CComposite_Contrast,
                _CComposite_ShadowColor,
                _CComposite_MidtoneColor,
                _CComposite_HighlightColor,
                _CComposite_ShadowOffset,
                _CComposite_MidtoneOffset,
                _CComposite_HighlightOffset
            );
        #elif CCOMPOSITE_TOGGLE_TONEMAP
            Color = CColor_ApplyTonemap(Color, _CComposite_Tonemapper);
        #else
            Color = Color;
        #endif
    }

#endif
