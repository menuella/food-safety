# food-safety (Ruby)

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

**No runtime dependencies.** `json` is a default gem, so the gem ships the canonical dataset and reads it directly.

```sh
bundle add menuella-food_safety
```

```ruby
require "menuella/food_safety"
```

The gem is `menuella-food_safety` and the module is `Menuella::FoodSafety` — a dash separates the namespace, an underscore joins words inside it. A plain `menuella-food-safety` would claim to be `Menuella::Food::Safety`.

## Use it

```ruby
de = Menuella::FoodSafety.disclosures("de")

wheat = de.allergens.find { _1.key == "WHEAT" }
wheat.name         # => "Weizen"
wheat.declaration  # => "Enthält Getreide und glutenhaltige Erzeugnisse"
```

Hand it the locale your application already resolved. **This gem does no i18n**: an unknown locale raises `UnsupportedLocaleError`, because a silently wrong language on an allergen panel is worse than a loud failure.

```ruby
rescue Menuella::FoodSafety::Error => e   # the base class of both errors
```

Everything it returns is **frozen**. The dataset is shared state, and a caller that could push onto an allergen list would be editing every other caller's copy in the same process.

## Keys, not codes

A product row stores `WHEAT` — not `A6`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template:

```ruby
codes = Menuella::FoodSafety.codes
codes.allergens["WHEAT"]         # => "A6"
codes.declarations["SWEETENERS"] # => "12"
```

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, only 12 selectable. The law requires naming the specific grain or nut, so you store `WHEAT` and render the group declaration above it.

## Icons

15 glyphs, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means. Every shape paints with `currentColor`, so a glyph follows the surrounding text colour and a light or dark theme with no second asset.

```ruby
Menuella::FoodSafety.icon("cereals").view_box  # => "0 0 24 24"

Menuella::FoodSafety.icon_to_svg("cereals", size: 16, css_class: "h-4 w-4")
```

Attributes are sorted rather than taken in the order the generator wrote them, so the markup is byte-stable — snapshot tests and any cache keyed on the output depend on it. `title:` and `css_class:` are escaped.

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it. `icon_to_svg` emits `aria-hidden` unless you pass a `title:`.

## API

| | |
| --- | --- |
| `.disclosures(locale)` | every allergen and declaration for a locale |
| `.codes` · `.code_scheme` | the footnote-code scheme |
| `.icon(name)` · `.icon_to_svg(name, **opts)` | glyphs as data or markup |
| `.locales` · `.fallback_locale` | the six supported locales |
| `.allergen_keys` · `.declaration_keys` · `.icon_names` | the vocabularies |
| `.locale?` · `.allergen_key?` · `.declaration_key?` | guards for untrusted input |
| `.dataset(name)` | the raw packaged JSON, for tooling |
| `UnsupportedLocaleError` · `UnknownIconError` | both descend from `Error` |

## Same data, other ecosystems

| | |
| --- | --- |
| RubyGems | this gem |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |
| Packagist | [`menuella/food-safety`](https://packagist.org/packages/menuella/food-safety) |
| crates.io | [`menuella-food-safety`](https://crates.io/crates/menuella-food-safety) |
| Go | [`github.com/menuella/food-safety/packages/go`](https://pkg.go.dev/github.com/menuella/food-safety/packages/go) |
| Swift | `MenuellaFoodSafety` |
| Maven Central | `com.menuella:food-safety` |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and declarations commonly required alongside them. **Which disclosures a business must make, and how, is a matter for that business and its jurisdiction.**

## License

MIT.
