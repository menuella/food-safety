# MenuellaFoodSafety

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

Pure Swift, **no dependencies**, `Sendable` throughout, Swift 6 language mode.

## Install

```swift
dependencies: [
    .package(url: "https://github.com/menuella/food-safety.git", from: "1.2.0")
]
```

In Xcode: **File → Add Package Dependencies**, then `https://github.com/menuella/food-safety`.

Supports iOS 15, macOS 12, tvOS 15, watchOS 8 and visionOS 1.

## Use it

```swift
import MenuellaFoodSafety

let de = try FoodSafety.disclosures(locale: "de")

let wheat = de.allergens.first { $0.key == "WHEAT" }
wheat?.name         // "Weizen"
wheat?.declaration  // "Enthält Getreide und glutenhaltige Erzeugnisse"
wheat?.icon         // "cereals"
```

Hand it the locale your app already resolved. **This package does no i18n**: an unknown locale throws `FoodSafetyError.unsupportedLocale`, because a silently wrong language on an allergen panel is worse than a loud failure. Ask `isLocale(_:)` first if you are not sure.

## Keys, not codes

A product row stores `WHEAT` — not `A6`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template:

```swift
try FoodSafety.codes().allergens["WHEAT"]  // "A6"
```

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, only 12 selectable. The law requires naming the specific grain or nut, so you store `WHEAT` and render the group declaration above it.

## Icons

15 glyphs, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means. Every shape paints with `currentColor`, so a glyph follows the surrounding text colour and light/dark with no second asset.

```swift
let glyph = try FoodSafety.icon(named: wheat!.icon)
glyph.viewBox               // "0 0 24 24"
glyph.nodes.first?.tag      // "path"

try FoodSafety.iconToSVG(named: "cereals", size: 16)   // for HTML, e-mail, PDF
```

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it — someone using VoiceOver, or who simply does not recognise the glyph, must still get the declaration.

They are decorative by default: `iconToSVG` emits `aria-hidden` unless you pass a `title`. In SwiftUI, mark the glyph `.accessibilityHidden(true)` and let the adjacent `Text` carry the meaning.

## A note on `description`

`Allergen` and `Declaration` spell their long-form field `entryDescription`, not `description`. A stored property named `description` on a public type shadows `CustomStringConvertible`, so `"\(allergen)"` would silently print that one field instead of the struct. The JSON key is unchanged.

## API

| | |
| --- | --- |
| `FoodSafety.disclosures(locale:)` | every allergen and declaration for a locale |
| `FoodSafety.codes()` | the footnote-code scheme |
| `FoodSafety.icon(named:)` | a glyph as `Icon(viewBox, nodes)` |
| `FoodSafety.iconToSVG(named:size:cssClass:title:)` | a glyph as an `<svg>` string |
| `FoodSafety.locales` | the six supported locales |
| `allergenKeys()` · `declarationKeys()` · `iconNames()` | the vocabularies |
| `isLocale(_:)` · `isAllergenKey(_:)` · `isDeclarationKey(_:)` | guards for untrusted input |

## Same data, other ecosystems

| | |
| --- | --- |
| Swift | this package |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |
| Packagist | [`menuella/food-safety`](https://packagist.org/packages/menuella/food-safety) |
| Maven Central | `com.menuella:food-safety` |
| crates.io | [`menuella-food-safety`](https://crates.io/crates/menuella-food-safety) |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and declarations commonly required alongside them. **Which disclosures a business must make, and how, is a matter for that business and its jurisdiction.**

## License

MIT.
