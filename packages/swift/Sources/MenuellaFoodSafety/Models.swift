import Foundation

/// One allergen, resolved for a locale.
public struct Allergen: Codable, Hashable, Sendable {
    /// The stored identifier, e.g. `WHEAT`. This is what a product row holds.
    public let key: String

    /// Its LMIV group, e.g. `CEREALS`.
    ///
    /// Twelve groups are also selectable keys; `CEREALS` and `TREE_NUTS` are
    /// display-only, because the law requires naming the specific grain or nut.
    public let group: String

    /// True when this key is one member of a multi-member group.
    public let isMember: Bool

    /// The glyph name, e.g. `cereals`.
    public let icon: String

    /// Short label, e.g. "Wheat".
    public let name: String

    /// The sentence with legal force. This is what must reach the guest.
    public let declaration: String

    /// A longer explanation, for tooltips and help text.
    ///
    /// Spelled `entryDescription` in Swift: a stored property named
    /// `description` on a public type shadows `CustomStringConvertible`, so
    /// every `"\(allergen)"` would silently print this field instead of the
    /// struct. The JSON key is unchanged.
    public let entryDescription: String

    private enum CodingKeys: String, CodingKey {
        case key, group, isMember, icon, name, declaration
        case entryDescription = "description"
    }
}

/// One declaration — an additive, beverage or product note — for a locale.
public struct Declaration: Codable, Hashable, Sendable {
    /// The stored identifier, e.g. `COLORING`.
    public let key: String

    /// One of `ADDITIVE`, `BEVERAGE`, `WARNING`, `PRODUCT`.
    public let category: String

    /// The glyph name. All declarations share one generic glyph.
    ///
    /// Non-optional: every declaration in the dataset carries one, and a test
    /// asserts that stays true.
    public let icon: String

    /// Short label, e.g. "With Coloring Agent".
    public let name: String

    /// A longer explanation. See ``Allergen/entryDescription`` for the name.
    public let entryDescription: String

    private enum CodingKeys: String, CodingKey {
        case key, category, icon, name
        case entryDescription = "description"
    }
}

/// Every disclosure for one locale, ready to render.
public struct Disclosures: Codable, Hashable, Sendable {
    public let locale: String

    /// The locale this bundle falls back to for anything it does not carry.
    public let fallbackLocale: String

    public let allergens: [Allergen]
    public let declarations: [Declaration]
}

/// The footnote-code scheme: letters for allergens, numbers for declarations.
public struct Codes: Codable, Hashable, Sendable {
    public let scheme: String
    public let convention: String

    /// Allergen key to its printable code, e.g. `WHEAT` → `A6`.
    public let allergens: [String: String]

    /// Declaration key to its printable code, e.g. `SWEETENERS` → `12`.
    public let declarations: [String: String]
}

/// A single shape in a glyph.
public struct IconNode: Hashable, Sendable {
    /// `path` or `circle`.
    public let tag: String

    /// Attribute names in SVG spelling (`fill-rule`, not `fillRule`).
    public let attributes: [String: String]
}

/// A glyph as data, for callers that build shapes rather than markup.
public struct Icon: Hashable, Sendable {
    /// Always `"0 0 24 24"`.
    public let viewBox: String

    public let nodes: [IconNode]
}
