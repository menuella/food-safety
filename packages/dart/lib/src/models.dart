/// One allergen, resolved for a locale.
class Allergen {
  /// Creates an allergen. Instances come from [getDisclosures]; you should
  /// not need to build one.
  const Allergen(
    this.key,
    this.group,
    this.isMember,
    this.icon,
    this.name,
    this.declaration,
    this.description,
  );

  /// The stored identifier, e.g. `WHEAT`. This is what a product row holds.
  final String key;

  /// The LMIV group, e.g. `CEREALS`. Twelve groups are also selectable keys;
  /// `CEREALS` and `TREE_NUTS` are display-only, because the law requires
  /// naming the specific grain or nut.
  final String group;

  /// True when this key is one member of a multi-member group.
  final bool isMember;

  /// The glyph name, e.g. `cereals`.
  final String icon;

  /// Short label, e.g. "Wheat".
  final String name;

  /// The sentence with legal force, e.g. "Contains cereals and
  /// gluten-containing products". This is what must reach the guest.
  final String declaration;

  /// A longer explanation, for tooltips and help text.
  final String description;
}

/// One declaration — an additive, beverage or product note — for a locale.
class Declaration {
  /// Creates a declaration. Instances come from [getDisclosures].
  const Declaration(
    this.key,
    this.category,
    this.icon,
    this.name,
    this.description,
  );

  /// The stored identifier, e.g. `COLORING`.
  final String key;

  /// One of `ADDITIVE`, `BEVERAGE`, `WARNING`, `PRODUCT`.
  final String category;

  /// The glyph name. All declarations share one generic glyph.
  final String icon;

  /// Short label, e.g. "With Coloring Agent".
  final String name;

  /// A longer explanation.
  final String description;
}

/// Every disclosure for one locale, ready to render.
class DisclosureSet {
  /// Creates a disclosure set. Instances come from [getDisclosures].
  const DisclosureSet({
    required this.locale,
    required this.fallbackLocale,
    required this.allergens,
    required this.declarations,
  });

  /// The locale these entries are resolved for.
  final String locale;

  /// The locale this bundle falls back to for anything it does not carry.
  final String fallbackLocale;

  /// Every allergen, in canonical dataset order.
  final List<Allergen> allergens;

  /// Every declaration, in canonical dataset order.
  final List<Declaration> declarations;
}

/// A single shape in a glyph: the tag and its SVG attributes.
class IconNode {
  /// Creates an icon node. Instances come from [getIcon].
  const IconNode(this.tag, this.attributes);

  /// `path` or `circle`.
  final String tag;

  /// Attribute names in SVG spelling (`fill-rule`, not `fillRule`).
  final Map<String, String> attributes;
}

/// A glyph as data, for callers that build widgets rather than markup.
class Icon {
  /// Creates an icon. Instances come from [getIcon].
  const Icon({required this.viewBox, required this.nodes});

  /// Always `"0 0 24 24"`.
  final String viewBox;

  /// The shapes to draw, in paint order.
  final List<IconNode> nodes;
}
