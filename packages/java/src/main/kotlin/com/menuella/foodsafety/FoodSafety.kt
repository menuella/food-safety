package com.menuella.foodsafety

/**
 * The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens and
 * the Menuella declarations, in six languages.
 *
 * Semantic keys instead of country-specific numbers — store the key, render the
 * code, never the reverse.
 *
 * ```kotlin
 * val de = FoodSafety.getDisclosures("de")
 * de.allergens.first { it.key == "WHEAT" }.declaration
 * // "Enthält Getreide und glutenhaltige Erzeugnisse"
 * ```
 *
 * This object does **not** do i18n. Hand it the locale your app already
 * resolved; it will not sniff, negotiate, or quietly fall back.
 *
 * Everything here is generated from the same JSON the npm package ships, so the
 * vocabulary cannot drift between languages. Nothing is parsed at runtime,
 * which is also why the artifact has no dependencies.
 */
public object FoodSafety {

    /** Locales with a prebuilt bundle. */
    @JvmStatic
    public val locales: List<String> = GENERATED_LOCALES

    /** The locale a bundle falls back to for anything it does not itself carry. */
    @JvmStatic
    public val fallbackLocale: String = GENERATED_FALLBACK_LOCALE

    /** The footnote-code scheme these codes belong to. */
    @JvmStatic
    public val codeScheme: String = GENERATED_CODE_SCHEME

    /** Every selectable allergen key, in canonical order. */
    @JvmStatic
    public val allergenKeys: List<String> = GENERATED_ALLERGEN_KEYS

    /** Every declaration key, in canonical order. */
    @JvmStatic
    public val declarationKeys: List<String> = GENERATED_DECLARATION_KEYS

    /**
     * Built once, and only if asked for. A `by lazy` rather than an eager val
     * so a consumer that only touches the vocabulary never pays for the glyph
     * data.
     */
    private val icons: Map<String, Icon> by lazy(LazyThreadSafetyMode.PUBLICATION) { generatedIcons() }

    /**
     * Every icon name that has a glyph.
     *
     * Lazy, not an eager val. Object initializers run in DECLARATION ORDER, so
     * an eager `icons.keys.sorted()` reads `icons` before its delegate exists —
     * which the compiler catches here, but which would be a null at runtime in
     * a language that let it through.
     */
    @JvmStatic
    public val iconNames: List<String> by lazy { icons.keys.sorted() }

    private val allergenSet: Set<String> = GENERATED_ALLERGEN_KEYS.toSet()
    private val declarationSet: Set<String> = GENERATED_DECLARATION_KEYS.toSet()

    /**
     * Bundles are built on first request and kept. Rebuilding per call would
     * allocate ~300 objects each time on what is often a per-request path.
     */
    private val cache = java.util.concurrent.ConcurrentHashMap<String, Disclosures>()

    /** True when [value] is a locale with a bundle. */
    @JvmStatic
    public fun isLocale(value: String?): Boolean = value != null && value in GENERATED_LOCALES

    /** True when [value] is a current allergen key. Retired keys return false. */
    @JvmStatic
    public fun isAllergenKey(value: String?): Boolean = value != null && value in allergenSet

    /** True when [value] is a current declaration key. */
    @JvmStatic
    public fun isDeclarationKey(value: String?): Boolean = value != null && value in declarationSet

    /**
     * Every disclosure for [locale], ready to render.
     *
     * Throws [IllegalArgumentException] if the locale has no bundle. It throws
     * rather than falling back because a silently wrong language on an allergen
     * panel is worse than a loud failure — the caller knows which locales it
     * supports, and [isLocale] is there to ask.
     */
    @JvmStatic
    public fun getDisclosures(locale: String): Disclosures =
        cache.computeIfAbsent(locale) {
            bundleFor(it)
                ?: throw IllegalArgumentException(
                    "No disclosures for locale \"$it\". Available: ${GENERATED_LOCALES.joinToString(", ")}."
                )
        }

    /**
     * The glyph named [name], as data.
     *
     * Every shape paints with `currentColor`, so a glyph inherits the
     * surrounding text colour and follows a light/dark theme with no second
     * asset.
     *
     * Throws [IllegalArgumentException] if the name has no glyph.
     */
    @JvmStatic
    public fun getIcon(name: String): Icon =
        icons[name]
            ?: throw IllegalArgumentException(
                "No icon named \"$name\". Available: ${iconNames.joinToString(", ")}."
            )

    /**
     * The glyph named [name] as an `<svg>` string, for templates that
     * interpolate markup — Thymeleaf, e-mail, PDF.
     *
     * Decorative by default: emits `aria-hidden` unless [title] is given, which
     * switches it to `role="img"` with a `<title>`. These glyphs carry legal
     * meaning, so render one *alongside* its declaration text, never instead of
     * it — the safe default is the free one.
     *
     * Throws [IllegalArgumentException] if the name has no glyph.
     */
    @JvmStatic
    @JvmOverloads
    public fun iconToSvg(
        name: String,
        size: Int = 24,
        cssClass: String? = null,
        title: String? = null,
    ): String {
        val icon = getIcon(name)
        val out = StringBuilder(512)

        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"")
            .append(escape(icon.viewBox))
            .append("\" width=\"").append(size)
            .append("\" height=\"").append(size)
            .append("\" fill=\"none\"")

        if (!cssClass.isNullOrEmpty()) {
            out.append(" class=\"").append(escape(cssClass)).append('"')
        }

        if (title.isNullOrEmpty()) {
            out.append(" aria-hidden=\"true\" focusable=\"false\">")
        } else {
            out.append(" role=\"img\"><title>").append(escape(title)).append("</title>")
        }

        for (node in icon.nodes) {
            out.append('<').append(node.tag)
            for ((key, value) in node.attributes) {
                out.append(' ').append(key).append("=\"").append(escape(value)).append('"')
            }
            out.append("/>")
        }

        return out.append("</svg>").toString()
    }

    /** The path data is ours, but [iconToSvg]'s title is caller-supplied. */
    private fun escape(value: String): String =
        value.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&#39;")
}
