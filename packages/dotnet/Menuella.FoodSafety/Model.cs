using System.Text.Json.Serialization;

namespace Menuella.FoodSafety;

/// <summary>One allergen, resolved for a locale.</summary>
/// <param name="Key">The stored identifier, e.g. <c>WHEAT</c>. This is what a product row holds.</param>
/// <param name="Group">Its LMIV group, e.g. <c>CEREALS</c>. Twelve groups are also selectable keys;
/// <c>CEREALS</c> and <c>TREE_NUTS</c> are display-only, because the law requires naming the
/// specific grain or nut.</param>
/// <param name="IsMember">True when this key is one member of a multi-member group.</param>
/// <param name="Icon">The glyph name, e.g. <c>cereals</c>. See <see cref="Icons"/>.</param>
/// <param name="Name">Short label, e.g. "Wheat".</param>
/// <param name="Declaration">The sentence with legal force, e.g. "Contains cereals and
/// gluten-containing products". This is what must reach the guest.</param>
/// <param name="Description">A longer explanation, for tooltips and help text.</param>
public sealed record Allergen(
    string Key,
    string Group,
    bool IsMember,
    string Icon,
    string Name,
    string Declaration,
    string Description);

/// <summary>One declaration — an additive, beverage or product note — resolved for a locale.</summary>
/// <param name="Key">The stored identifier, e.g. <c>COLORING</c>.</param>
/// <param name="Category">One of <c>ADDITIVE</c>, <c>BEVERAGE</c>, <c>WARNING</c>, <c>PRODUCT</c>.</param>
/// <param name="Icon">The glyph name. All declarations share one generic glyph.</param>
/// <param name="Name">Short label, e.g. "With Coloring Agent".</param>
/// <param name="Description">A longer explanation.</param>
public sealed record Declaration(
    string Key,
    string Category,
    string Icon,
    string Name,
    string Description);

/// <summary>Every disclosure for one locale, ready to render.</summary>
public sealed record DisclosureSet(
    string Locale,
    string FallbackLocale,
    IReadOnlyList<Allergen> Allergens,
    IReadOnlyList<Declaration> Declarations);

/// <summary>A single shape in a glyph: the tag, plus its SVG attributes.</summary>
/// <param name="Tag"><c>path</c> or <c>circle</c>.</param>
/// <param name="Attributes">Attribute names in SVG spelling (<c>fill-rule</c>, not <c>fillRule</c>).</param>
public sealed record IconNode(string Tag, IReadOnlyDictionary<string, string> Attributes);

/// <summary>A glyph as data, for callers that build elements rather than markup.</summary>
public sealed record Icon(string ViewBox, IReadOnlyList<IconNode> Nodes);

// ---------------------------------------------------------------------------
// Wire shapes. Separate from the public records because the JSON uses camelCase
// and a raw node is a heterogeneous array — neither of which belongs in an API.

internal sealed record BundleDto(
    string Locale,
    string FallbackLocale,
    List<AllergenDto> Allergens,
    List<DeclarationDto> Declarations);

internal sealed record AllergenDto(
    string Key, string Group, bool IsMember, string Icon,
    string Name, string Declaration, string Description);

internal sealed record DeclarationDto(
    string Key, string Category, string Icon, string Name, string Description);

internal sealed record CodesDto(string Scheme);
