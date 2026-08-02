# menuella/food-safety

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

PHP 8.2+, **no dependencies** beyond `ext-json`, and everything is `readonly`.

```sh
composer require menuella/food-safety
```

## Use it

```php
use Menuella\FoodSafety\FoodSafety;

$de = FoodSafety::getDisclosures('de');

$wheat = current(array_filter($de->allergens, fn ($a) => $a->key === 'WHEAT'));
$wheat->name;        // 'Weizen'
$wheat->declaration; // 'Enthält Getreide und glutenhaltige Erzeugnisse'
$wheat->icon;        // 'cereals'
```

Hand it the locale your app already resolved. **This package does no i18n**: an unknown locale throws `InvalidArgumentException`, because a silently wrong language on an allergen panel is worse than a loud failure. Ask `isLocale()` first if you are not sure.

## Keys, not codes

A product row stores `WHEAT` — not `A1`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template.

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, only 12 selectable. The law requires naming the specific grain or nut, so you store `WHEAT` and render the group declaration above it.

## Icons

15 glyphs, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means. Every shape paints with `currentColor`, so a glyph follows the surrounding text colour and a light/dark theme with no second asset.

```php
FoodSafety::iconToSvg($wheat->icon, size: 16, cssClass: 'allergen-icon');
```

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it. They are decorative by default: `iconToSvg()` emits `aria-hidden="true"` unless you pass a `title`.

## API

| | |
| --- | --- |
| `FoodSafety::getDisclosures($locale)` | every allergen and declaration for a locale |
| `FoodSafety::getIcon($name)` | a glyph as `Icon(viewBox, nodes)` |
| `FoodSafety::iconToSvg($name, …)` | a glyph as an `<svg>` string |
| `FoodSafety::loadDataset()` | the raw JSON, for tooling |
| `FoodSafety::LOCALES` | the six supported locales |
| `allergenKeys()` · `declarationKeys()` · `iconNames()` | the vocabularies |
| `isLocale()` · `isAllergenKey()` · `isDeclarationKey()` | guards for untrusted input |
| `codeScheme()` | `'MENUELLA'` |

## Same data, other ecosystems

| | |
| --- | --- |
| Packagist | `menuella/food-safety` |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |
| Maven Central | `com.menuella:food-safety` |
| crates.io | [`menuella-food-safety`](https://crates.io/crates/menuella-food-safety) |
| RubyGems | [`menuella-food_safety`](https://rubygems.org/gems/menuella-food_safety) |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and declarations commonly required alongside them. **Which disclosures a business must make, and how, is a matter for that business and its jurisdiction.**

## License

MIT.
