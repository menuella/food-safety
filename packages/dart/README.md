# menuella_food_safety

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

Pure Dart, **no dependencies**, and no `dart:io` — so it behaves identically on the VM, on Flutter, and on the web.

```sh
dart pub add menuella_food_safety
```

## Use it

```dart
import 'package:menuella_food_safety/menuella_food_safety.dart';

final de = getDisclosures('de');

final wheat = de.allergens.firstWhere((a) => a.key == 'WHEAT');
wheat.name;        // 'Weizen'
wheat.declaration; // 'Enthält Getreide und glutenhaltige Erzeugnisse'
wheat.icon;        // 'cereals'
```

Hand it the locale your app already resolved. **This package does no i18n**: it will not sniff the platform, negotiate, or quietly fall back — an unknown locale throws, because a silently wrong language on an allergen panel is worse than a loud failure. Ask `isLocale` first if you are not sure.

## Keys, not codes

A product row stores `WHEAT` — not `A1`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template. The key never changes meaning.

`CEREALS` and `TREE_NUTS` are **groups, not keys**: there are 14 groups but only 12 are selectable. The law requires naming the specific grain or nut, so you store `WHEAT` or `HAZELNUTS` and render the group declaration above it.

```dart
final selected = <String>{'WHEAT', 'MILK'};
final byGroup = <String, List<Allergen>>{};
for (final a in de.allergens.where((a) => selected.contains(a.key))) {
  byGroup.putIfAbsent(a.group, () => <Allergen>[]).add(a);
}
// CEREALS → 'Enthält Getreide und glutenhaltige Erzeugnisse', members: [Weizen]
// MILK    → 'Enthält Milch und Milcherzeugnisse (einschließlich Laktose)'
```

## Icons

15 glyphs, one per statutory allergen group, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means.

Every shape paints with `currentColor`, so a glyph inherits the surrounding text colour and follows a light/dark theme with no second asset.

```dart
// As data — build real widgets, no markup parsing.
final glyph = getIcon(wheat.icon);
glyph.viewBox;                // '0 0 24 24'
glyph.nodes.first.tag;        // 'path'
glyph.nodes.first.attributes; // {'fill': 'currentColor', 'd': '…'}

// Or as markup, for server-rendered HTML, e-mail and PDF.
iconToSvg(wheat.icon, size: 16, cssClass: 'allergen-icon');
```

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it — someone using a screen reader, or who simply does not recognise the glyph, must still get the declaration.

So they are decorative by default: `iconToSvg` emits `aria-hidden="true"` unless you pass a `title`. In Flutter, wrap the glyph in `ExcludeSemantics` and let the adjacent `Text` carry the meaning.

## API

| | |
| --- | --- |
| `getDisclosures(locale)` | every allergen and declaration for a locale |
| `getIcon(name)` | a glyph as `{ viewBox, nodes }` |
| `iconToSvg(name, …)` | a glyph as an `<svg>` string |
| `locales` | the six supported locales |
| `allergenKeys` · `declarationKeys` · `iconNames` | the vocabularies |
| `isLocale` · `isAllergenKey` · `isDeclarationKey` | guards for untrusted input |
| `codeScheme` · `fallbackLocale` | `'MENUELLA'` · `'en'` |

## Languages

German, English, French, Italian, Spanish and Turkish — every key complete in every one. No partial locales, so there is no fallback to reason about at render time.

## Same data, other ecosystems

This is one binding of a shared dataset. The vocabulary, the keys and the icons are identical across all of them, released from one tag:

| | |
| --- | --- |
| pub.dev | this package |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |
| Packagist | [`menuella/food-safety`](https://packagist.org/packages/menuella/food-safety) |
| crates.io | [`menuella-food-safety`](https://crates.io/crates/menuella-food-safety) |
| Go | [`github.com/menuella/food-safety/packages/go`](https://pkg.go.dev/github.com/menuella/food-safety/packages/go) |
| Swift | `MenuellaFoodSafety` |
| Maven Central | `com.menuella:food-safety` |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and a set of declarations commonly required alongside them. **Which disclosures a given business must make, and how, is a matter for that business and its jurisdiction.** This package gives you correct, complete, translated text to render — it does not decide what you are obliged to render.

## License

MIT — use it in your own products, with or without Menuella.
