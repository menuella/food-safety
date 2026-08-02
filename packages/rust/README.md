# food-safety (Rust)

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

**No dependencies, no parsing, no allocation.** The dataset is generated Rust source, so it lives in the binary's read-only section as `&'static str` — nothing is parsed at startup, and every table is reachable from a `const` context.

```sh
cargo add menuella-food-safety
```

## Use it

```rust
let de = menuella_food_safety::disclosures("de")?;

for allergen in de.allergens {
    if allergen.key == "WHEAT" {
        println!("{}", allergen.name);        // Weizen
        println!("{}", allergen.declaration); // Enthält Getreide und glutenhaltige Erzeugnisse
    }
}
```

Hand it the locale your application already resolved. **This crate does no i18n**: an unknown locale returns `UnsupportedLocale`, because a silently wrong language on an allergen panel is worse than a loud failure.

Because the data is `const`, a bundle can also be bound at compile time:

```rust
use menuella_food_safety as fs;

const DE: fs::Disclosures = match fs::disclosures_const("de") {
    Some(set) => set,
    None => panic!("de is a supported locale"),
};
```

## Keys, not codes

A product row stores `WHEAT` — not `A6`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template:

```rust
menuella_food_safety::allergen_code("WHEAT");          // Some("A6")
menuella_food_safety::declaration_code("SWEETENERS");  // Some("12")
```

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, only 12 selectable. The law requires naming the specific grain or nut, so you store `WHEAT` and render the group declaration above it.

## Icons

15 glyphs, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means. Every shape paints with `currentColor`, so a glyph follows the surrounding text colour and a light or dark theme with no second asset.

```rust
use menuella_food_safety::{icon, icon_to_svg, SvgOptions};

icon("cereals")?.view_box;  // "0 0 24 24"

let svg = icon_to_svg("cereals", SvgOptions { size: Some(16), ..Default::default() })?;
```

Attributes are pre-sorted by the generator, so the markup is byte-stable across runs — snapshot tests and any cache keyed on the output depend on it.

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it. `icon_to_svg` emits `aria-hidden` unless you pass a `title`.

## Optional `serde`

```toml
menuella-food-safety = { version = "1", features = ["serde"] }
```

Adds `Serialize` to every data type — enough to hand a bundle to an API response or a template engine. `Deserialize` is deliberately absent: every field borrows from the binary's static data, so there is nothing to deserialize *into*, and reading this vocabulary back from an untrusted document is the mistake the crate exists to prevent.

## API

| | |
| --- | --- |
| `disclosures(locale)` · `disclosures_const(locale)` | every allergen and declaration for a locale |
| `CODES` · `CODE_SCHEME` | the footnote-code scheme |
| `allergen_code(key)` · `declaration_code(key)` | a key's printable code |
| `icon(name)` · `icon_to_svg(name, opts)` | glyphs as data or markup |
| `LOCALES` · `FALLBACK_LOCALE` | the six supported locales |
| `ALLERGEN_KEYS` · `DECLARATION_KEYS` · `ICON_NAMES` | the vocabularies |
| `is_locale` · `is_allergen_key` · `is_declaration_key` | guards for untrusted input |
| `UnsupportedLocale` · `UnknownIcon` | the two error types |

## Same data, other ecosystems

| | |
| --- | --- |
| crates.io | this crate |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |
| Packagist | [`menuella/food-safety`](https://packagist.org/packages/menuella/food-safety) |
| Go | [`github.com/menuella/food-safety/packages/go`](https://pkg.go.dev/github.com/menuella/food-safety/packages/go) |
| Swift | `MenuellaFoodSafety` |
| Maven Central | `com.menuella:food-safety` |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and declarations commonly required alongside them. **Which disclosures a business must make, and how, is a matter for that business and its jurisdiction.**

## License

MIT.
