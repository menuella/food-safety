import Foundation
import Testing

@testable import MenuellaFoodSafety

/// Behaviour of the published surface, plus the one risk a copied dataset has.
///
/// The repository's own validation covers the canonical JSON. What it cannot
/// see is whether the copy inside this target is the same JSON — so the tests
/// that compare against the canonical `data/` are the ones that matter most
/// here. Without them, a release built without running the generator would ship
/// stale data and every other test would still pass.
private func repoRoot() -> URL? {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.path != "/" {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("data/allergens.json").path) {
            return dir
        }
        dir = dir.deletingLastPathComponent()
    }
    return nil
}

private func canonicalCount(_ file: String) throws -> Int? {
    guard let root = repoRoot() else { return nil }
    let data = try Data(contentsOf: root.appendingPathComponent("data/\(file)"))
    let rows = try JSONSerialization.jsonObject(with: data) as? [Any]
    return rows?.count
}

// MARK: - Disclosures

@Test func everyLocaleResolvesToACompleteBundle() throws {
    for locale in FoodSafety.locales {
        let set = try FoodSafety.disclosures(locale: locale)
        #expect(set.locale == locale)
        #expect(!set.allergens.isEmpty)
        #expect(!set.declarations.isEmpty)
        for allergen in set.allergens {
            #expect(!allergen.declaration.isEmpty, "\(locale)/\(allergen.key)")
            #expect(!allergen.name.isEmpty, "\(locale)/\(allergen.key)")
        }
    }
}

@Test func germanReadsCorrectly() throws {
    let de = try FoodSafety.disclosures(locale: "de")
    let wheat = de.allergens.first { $0.key == "WHEAT" }
    #expect(wheat?.name == "Weizen")
    #expect(wheat?.declaration == "Enthält Getreide und glutenhaltige Erzeugnisse")
    #expect(wheat?.icon == "cereals")
}

@Test func anUnsupportedLocaleThrowsRatherThanFallingBack() {
    #expect(throws: FoodSafetyError.unsupportedLocale("nl")) {
        try FoodSafety.disclosures(locale: "nl")
    }
}

@Test func guardsRejectKeysOutsideTheVocabulary() throws {
    #expect(try FoodSafety.isAllergenKey("WHEAT"))
    #expect(try FoodSafety.isAllergenKey("EGGS"))
    // "EGG" is another vocabulary's word for it, not a key here.
    #expect(try !FoodSafety.isAllergenKey("EGG"))
    #expect(try FoodSafety.isDeclarationKey("COLORING"))
    #expect(try !FoodSafety.isDeclarationKey("WHEAT"))
    #expect(FoodSafety.isLocale("de"))
    #expect(!FoodSafety.isLocale("nl"))
}

@Test func noDuplicateOrOverlappingKeys() throws {
    let allergens = try FoodSafety.allergenKeys()
    let declarations = try FoodSafety.declarationKeys()

    #expect(Set(allergens).count == allergens.count)
    #expect(Set(declarations).count == declarations.count)
    // The two vocabularies must not overlap, or a stored key is ambiguous.
    #expect(Set(allergens).intersection(declarations).isEmpty)
}

@Test func cerealsAndTreeNutsAreGroupsButNeverSelectableKeys() throws {
    let en = try FoodSafety.disclosures(locale: "en")
    let groups = Set(en.allergens.map(\.group))
    let keys = Set(en.allergens.map(\.key))

    #expect(groups.count == 14)
    // The law requires naming the specific grain or nut, so the umbrella group
    // is display-only and must not be storable.
    #expect(!keys.contains("CEREALS"))
    #expect(!keys.contains("TREE_NUTS"))
    #expect(groups.contains("CEREALS") && groups.contains("TREE_NUTS"))
}

@Test func everyDeclarationCarriesAnIcon() throws {
    // `Declaration.icon` is non-optional. If a declaration ever ships without
    // one, decoding breaks for every consumer — so assert it here rather than
    // discovering it as a decode failure in someone's app.
    let en = try FoodSafety.disclosures(locale: "en")
    #expect(en.declarations.allSatisfy { !$0.icon.isEmpty })
}

@Test func countsMatchTheCanonicalDatasetOnDisk() throws {
    #expect(try FoodSafety.allergenKeys().count == 28)
    #expect(try FoodSafety.declarationKeys().count == 22)

    // Skipped when running from a built artifact rather than the repository.
    if let allergens = try canonicalCount("allergens.json") {
        #expect(try FoodSafety.allergenKeys().count == allergens)
    }
    if let declarations = try canonicalCount("declarations.json") {
        #expect(try FoodSafety.declarationKeys().count == declarations)
    }
}

// MARK: - Codes

@Test func codesProjectKeysOntoPrintableCodes() throws {
    let codes = try FoodSafety.codes()
    #expect(codes.scheme == "MENUELLA")
    #expect(codes.allergens["WHEAT"] == "A6")
    #expect(codes.declarations["SWEETENERS"] == "12")
    #expect(try FoodSafety.codeScheme() == "MENUELLA")
}

// MARK: - Icons

@Test func everyIconTheDataReferencesHasAGlyphAndNoneIsUnused() throws {
    let en = try FoodSafety.disclosures(locale: "en")
    let referenced = Set(en.allergens.map(\.icon)).union(en.declarations.map(\.icon))

    for name in referenced {
        #expect(try !FoodSafety.icon(named: name).nodes.isEmpty, "\(name)")
    }
    #expect(try FoodSafety.iconNames() == referenced.sorted())
}

@Test func everyShapePaintsWithCurrentColor() throws {
    // Without this a glyph cannot follow the surrounding text colour, which is
    // the whole reason these are inlined rather than shipped as images.
    for name in try FoodSafety.iconNames() {
        for node in try FoodSafety.icon(named: name).nodes {
            #expect(node.attributes["fill"] == "currentColor", "\(name)/\(node.tag)")
        }
    }
}

@Test func markupUsesSVGAttributeSpellingNotTheReactOne() throws {
    let all = try FoodSafety.iconNames().map { try FoodSafety.iconToSVG(named: $0) }.joined()
    #expect(!all.contains("fillRule"))
    #expect(!all.contains("clipRule"))
    #expect(all.contains("fill-rule=\"evenodd\""))
}

@Test func svgIsDecorativeByDefaultAndNamedOnlyWithATitle() throws {
    let plain = try FoodSafety.iconToSVG(named: "milk")
    #expect(plain.contains("aria-hidden=\"true\""))
    #expect(plain.contains("focusable=\"false\""))
    #expect(!plain.contains("role=\"img\""))

    let titled = try FoodSafety.iconToSVG(named: "milk", title: "Milk")
    #expect(titled.contains("role=\"img\""))
    #expect(titled.contains("<title>Milk</title>"))
    #expect(!titled.contains("aria-hidden"))
}

@Test func aCallerSuppliedTitleCannotInjectMarkup() throws {
    let svg = try FoodSafety.iconToSVG(named: "milk", title: "</title><script>alert(1)</script>")
    #expect(!svg.contains("<script>"))
    #expect(svg.contains("&lt;script&gt;"))
}

@Test func markupIsDeterministic() throws {
    // A Swift Dictionary has no stable iteration order, so unsorted attributes
    // would produce different markup run to run — breaking snapshot tests and
    // any cache keyed on the output.
    let first = try FoodSafety.iconToSVG(named: "eggs")
    let second = try FoodSafety.iconToSVG(named: "eggs")
    #expect(first == second)
}

@Test func sizeAndClassReachTheRootElement() throws {
    let svg = try FoodSafety.iconToSVG(named: "eggs", size: 16, cssClass: "h-4 w-4")
    #expect(svg.contains("width=\"16\" height=\"16\""))
    #expect(svg.contains("class=\"h-4 w-4\""))
}

@Test func anUnknownIconThrows() {
    #expect(throws: FoodSafetyError.unknownIcon("wine")) {
        try FoodSafety.icon(named: "wine")
    }
}
