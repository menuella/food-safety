# food-safety (Go)

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

**No dependencies.** The dataset is embedded with `//go:embed`, so your binary is self-contained and there is nothing to find on disk at runtime.

```sh
go get github.com/menuella/food-safety/packages/go@latest
```

```go
import foodsafety "github.com/menuella/food-safety/packages/go"
```

## Use it

```go
de, err := foodsafety.GetDisclosures("de")
if err != nil {
    return err
}

for _, a := range de.Allergens {
    if a.Key == "WHEAT" {
        fmt.Println(a.Name)        // Weizen
        fmt.Println(a.Declaration) // Enthält Getreide und glutenhaltige Erzeugnisse
    }
}
```

Hand it the locale your application already resolved. **This package does no i18n**: an unknown locale returns an error wrapping `ErrUnsupportedLocale`, because a silently wrong language on an allergen panel is worse than a loud failure.

```go
if errors.Is(err, foodsafety.ErrUnsupportedLocale) { … }
```

## Keys, not codes

A product row stores `WHEAT` — not `A6`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template:

```go
codes, _ := foodsafety.GetCodes()
codes.Allergens["WHEAT"]        // "A6"
codes.Declarations["SWEETENERS"] // "12"
```

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, only 12 selectable. The law requires naming the specific grain or nut, so you store `WHEAT` and render the group declaration above it.

## Icons

15 glyphs, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means. Every shape paints with `currentColor`, so a glyph follows the surrounding text colour and a light or dark theme with no second asset.

```go
icon, _ := foodsafety.GetIcon("cereals")
icon.ViewBox                    // "0 0 24 24"

svg, _ := foodsafety.IconToSVG("cereals", foodsafety.SVGOptions{Size: 16})
```

Attributes are emitted in sorted order, so the markup is byte-stable across runs — Go randomises map iteration on purpose, and unstable output breaks snapshot tests and any cache keyed on it.

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it. `IconToSVG` emits `aria-hidden` unless you pass a `Title`.

## API

| | |
| --- | --- |
| `GetDisclosures(locale)` | every allergen and declaration for a locale |
| `GetCodes()` · `CodeScheme()` | the footnote-code scheme |
| `GetIcon(name)` · `IconToSVG(name, opts)` | glyphs as data or markup |
| `Locales()` | the six supported locales |
| `AllergenKeys()` · `DeclarationKeys()` · `IconNames()` | the vocabularies |
| `IsLocale` · `IsAllergenKey` · `IsDeclarationKey` | guards for untrusted input |
| `LoadDataset(name)` | the raw embedded JSON, for tooling |
| `ErrUnsupportedLocale` · `ErrUnknownIcon` | sentinels for `errors.Is` |

## Versioning

This is a **nested module**, so its releases carry the directory prefix:

```
packages/go/v1.3.0
```

A workflow derives that tag from the repository's plain `v1.3.0` on push, so both always point at the same commit.

## Same data, other ecosystems

| | |
| --- | --- |
| Go | this module |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |
| Packagist | [`menuella/food-safety`](https://packagist.org/packages/menuella/food-safety) |
| Swift | `MenuellaFoodSafety` |
| Maven Central | `com.menuella:food-safety` |
| crates.io | [`menuella-food-safety`](https://crates.io/crates/menuella-food-safety) |
| RubyGems | [`menuella-food_safety`](https://rubygems.org/gems/menuella-food_safety) |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and declarations commonly required alongside them. **Which disclosures a business must make, and how, is a matter for that business and its jurisdiction.**

## License

MIT.
