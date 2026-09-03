import Foundation

/// Everything that can go wrong reading the packaged dataset.
public enum FoodSafetyError: Error, LocalizedError, Sendable, Equatable {
    /// The locale has no bundle. ``FoodSafety/locales`` lists the ones that do.
    case unsupportedLocale(String)

    /// A resource is missing, which means the package was built without its data.
    case missingResource(String)

    /// A resource is present but could not be decoded.
    case invalidResource(String, underlying: String)

    /// The name has no glyph.
    case unknownIcon(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedLocale(locale):
            return "No disclosures for locale \"\(locale)\". "
                + "Available: \(FoodSafety.locales.joined(separator: ", "))."
        case let .missingResource(resource):
            return "Packaged dataset is missing \(resource)."
        case let .invalidResource(resource, underlying):
            return "Could not decode \(resource): \(underlying)"
        case let .unknownIcon(name):
            return "No icon named \"\(name)\"."
        }
    }
}

/// The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens
/// and the Menuella declarations, in six languages.
///
/// Semantic keys instead of country-specific numbers — store the key, render
/// the code, never the reverse.
///
/// ```swift
/// let de = try FoodSafety.disclosures(locale: "de")
/// de.allergens.first { $0.key == "WHEAT" }?.declaration
/// // "Enthält Getreide und glutenhaltige Erzeugnisse"
/// ```
///
/// This type does **not** do i18n. Hand it the locale your app already
/// resolved; it will not sniff, negotiate, or quietly fall back.
public enum FoodSafety {

    /// Locales with a prebuilt bundle.
    public static let locales: [String] = ["de", "en", "es", "fr", "it", "tr"]

    /// The locale a bundle falls back to for anything it does not itself carry.
    public static let fallbackLocale = "en"

    // Decoded bundles are cached behind a lock rather than recomputed. A
    // `static var` would not be Sendable under strict concurrency, and an actor
    // would force every call site to be async for what is a pure lookup.
    private static let cache = Cache()

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var bundles: [String: Disclosures] = [:]
        private var icons: [String: Icon]?
        private var codes: Codes?

        func bundle(_ locale: String, _ make: () throws -> Disclosures) rethrows -> Disclosures {
            lock.lock()
            defer { lock.unlock() }
            if let hit = bundles[locale] { return hit }
            let made = try make()
            bundles[locale] = made
            return made
        }

        func allIcons(_ make: () throws -> [String: Icon]) rethrows -> [String: Icon] {
            lock.lock()
            defer { lock.unlock() }
            if let hit = icons { return hit }
            let made = try make()
            icons = made
            return made
        }

        func allCodes(_ make: () throws -> Codes) rethrows -> Codes {
            lock.lock()
            defer { lock.unlock() }
            if let hit = codes { return hit }
            let made = try make()
            codes = made
            return made
        }
    }

    // MARK: - Disclosures

    /// Every disclosure for `locale`, ready to render.
    ///
    /// Throws rather than falling back: a silently wrong language on an
    /// allergen panel is worse than a loud failure. The caller knows which
    /// locales it supports, and ``isLocale(_:)`` is there to ask.
    public static func disclosures(locale: String) throws -> Disclosures {
        guard isLocale(locale) else {
            throw FoodSafetyError.unsupportedLocale(locale)
        }
        return try cache.bundle(locale) {
            try decode(Disclosures.self, named: locale, in: "Data/bundles")
        }
    }

    /// The footnote-code scheme: letters for allergens, numbers for declarations.
    public static func codes() throws -> Codes {
        try cache.allCodes { try decode(Codes.self, named: "codes", in: "Data") }
    }

    /// The scheme these codes belong to.
    public static func codeScheme() throws -> String { try codes().scheme }

    // MARK: - Vocabulary

    /// Every selectable allergen key, in canonical order.
    ///
    /// Derived from the dataset, never hand-listed. Keys are locale-independent,
    /// so this reads the fallback bundle rather than taking a locale argument.
    public static func allergenKeys() throws -> [String] {
        try disclosures(locale: fallbackLocale).allergens.map(\.key)
    }

    /// Every declaration key, in canonical order.
    public static func declarationKeys() throws -> [String] {
        try disclosures(locale: fallbackLocale).declarations.map(\.key)
    }

    /// Every icon name that has a glyph.
    public static func iconNames() throws -> [String] {
        try allIcons().keys.sorted()
    }

    /// True when `value` is a locale with a bundle.
    public static func isLocale(_ value: String) -> Bool { locales.contains(value) }

    /// True when `value` is a current allergen key. Retired keys return false.
    public static func isAllergenKey(_ value: String) throws -> Bool {
        try allergenKeys().contains(value)
    }

    /// True when `value` is a current declaration key.
    public static func isDeclarationKey(_ value: String) throws -> Bool {
        try declarationKeys().contains(value)
    }

    // MARK: - Icons

    /// The glyph named `name`, as data.
    ///
    /// Every shape paints with `currentColor`, so a glyph inherits the
    /// surrounding text colour and follows light and dark with no second asset.
    public static func icon(named name: String) throws -> Icon {
        guard let icon = try allIcons()[name] else {
            throw FoodSafetyError.unknownIcon(name)
        }
        return icon
    }

    /// The glyph named `name` as an `<svg>` string, for anything that
    /// interpolates markup — server-rendered HTML, e-mail, PDF.
    ///
    /// Decorative by default: emits `aria-hidden` unless `title` is given,
    /// which switches it to `role="img"` with a `<title>`. These glyphs carry
    /// legal meaning, so render one *alongside* its declaration text, never
    /// instead of it — the safe default is the free one.
    public static func iconToSVG(
        named name: String,
        size: Int = 24,
        cssClass: String? = nil,
        title: String? = nil
    ) throws -> String {
        let icon = try icon(named: name)
        var out = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox=""#
        out += escape(icon.viewBox)
        out += "\" width=\"\(size)\" height=\"\(size)\" fill=\"none\""

        if let cssClass, !cssClass.isEmpty {
            out += " class=\"\(escape(cssClass))\""
        }

        if let title, !title.isEmpty {
            out += " role=\"img\"><title>\(escape(title))</title>"
        } else {
            out += " aria-hidden=\"true\" focusable=\"false\">"
        }

        for node in icon.nodes {
            out += "<\(node.tag)"
            // Sorted so the output is deterministic — a Swift Dictionary has no
            // stable order, and unstable markup breaks snapshot tests and caches.
            for key in node.attributes.keys.sorted() {
                out += " \(key)=\"\(escape(node.attributes[key]!))\""
            }
            out += "/>"
        }

        return out + "</svg>"
    }

    // MARK: - Loading

    // The JSON carries React attribute spelling, because its first consumer is
    // React. Markup needs the SVG one — and an unmapped name still draws, just
    // without the even-odd rule, so the bug would be a subtly wrong glyph
    // rather than a missing one.
    private static let svgAttribute = ["fillRule": "fill-rule", "clipRule": "clip-rule"]

    private static func allIcons() throws -> [String: Icon] {
        try cache.allIcons {
            // Decoded by hand rather than through Codable: a node is
            // ["path", { … }] — a heterogeneous array whose first element is a
            // string and second an object — which Codable models badly.
            let raw = try decode([String: RawIcon].self, named: "icons", in: "Data")
            return raw.mapValues { icon in
                Icon(
                    viewBox: icon.viewBox,
                    nodes: icon.nodes.map { node in
                        IconNode(
                            tag: node.tag,
                            attributes: Dictionary(
                                uniqueKeysWithValues: node.attributes.map {
                                    (svgAttribute[$0.key] ?? $0.key, $0.value)
                                }
                            )
                        )
                    }
                )
            }
        }
    }

    private struct RawIcon: Decodable {
        let viewBox: String
        let nodes: [RawNode]

        struct RawNode: Decodable {
            let tag: String
            let attributes: [String: String]

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                tag = try container.decode(String.self)
                attributes = try container.decode([String: String].self)
            }
        }
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        named name: String,
        in subdirectory: String
    ) throws -> T {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: subdirectory
        ) else {
            throw FoodSafetyError.missingResource("\(subdirectory)/\(name).json")
        }

        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            throw FoodSafetyError.invalidResource(
                "\(name).json",
                underlying: String(describing: error)
            )
        }
    }

    /// The path data is ours, but `iconToSVG`'s title is caller-supplied.
    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
