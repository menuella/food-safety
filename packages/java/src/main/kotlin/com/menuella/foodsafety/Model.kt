package com.menuella.foodsafety

/**
 * One allergen, resolved for a locale.
 *
 * @property key the stored identifier, e.g. `WHEAT` — what a product row holds
 * @property group its LMIV group, e.g. `CEREALS`. Twelve groups are also
 *   selectable keys; `CEREALS` and `TREE_NUTS` are display-only, because the
 *   law requires naming the specific grain or nut.
 * @property isMember true when this key is one member of a multi-member group
 * @property icon the glyph name, e.g. `cereals`
 * @property name short label, e.g. "Wheat"
 * @property declaration the sentence with legal force — what must reach the guest
 * @property description a longer explanation, for tooltips and help text
 */
public data class Allergen(
    public val key: String,
    public val group: String,
    public val isMember: Boolean,
    public val icon: String,
    public val name: String,
    public val declaration: String,
    public val description: String,
)

/**
 * One declaration — an additive, beverage or product note — for a locale.
 *
 * @property key the stored identifier, e.g. `COLORING`
 * @property category one of `ADDITIVE`, `BEVERAGE`, `WARNING`, `PRODUCT`
 * @property icon the glyph name; all declarations share one generic glyph
 * @property name short label, e.g. "With Coloring Agent"
 * @property description a longer explanation
 */
public data class Declaration(
    public val key: String,
    public val category: String,
    public val icon: String,
    public val name: String,
    public val description: String,
)

/** Every disclosure for one locale, ready to render. */
public data class Disclosures(
    public val locale: String,
    /** The locale this bundle falls back to for anything it does not carry. */
    public val fallbackLocale: String,
    public val allergens: List<Allergen>,
    public val declarations: List<Declaration>,
)

/**
 * A single shape in a glyph.
 *
 * @property tag `path` or `circle`
 * @property attributes attribute names in SVG spelling (`fill-rule`, not `fillRule`)
 */
public data class IconNode(
    public val tag: String,
    public val attributes: Map<String, String>,
)

/** A glyph as data, for callers that build elements rather than markup. */
public data class Icon(
    /** Always `"0 0 24 24"`. */
    public val viewBox: String,
    public val nodes: List<IconNode>,
)
