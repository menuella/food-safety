# com.menuella:food-safety

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

Kotlin, JVM 17+, **no dependencies beyond `kotlin-stdlib`**, and nothing parsed at runtime — the dataset is generated Kotlin source, so it works on Android and in a Native Image without reflection or resource configuration.

## Install

```kotlin
// build.gradle.kts
implementation("com.menuella:food-safety:1.2.0")
```

```xml
<dependency>
  <groupId>com.menuella</groupId>
  <artifactId>food-safety</artifactId>
  <version>1.2.0</version>
</dependency>
```

## Use it

```kotlin
import com.menuella.foodsafety.FoodSafety

val de = FoodSafety.getDisclosures("de")

val wheat = de.allergens.first { it.key == "WHEAT" }
wheat.name         // "Weizen"
wheat.declaration  // "Enthält Getreide und glutenhaltige Erzeugnisse"
wheat.icon         // "cereals"
```

From Java, every member is `@JvmStatic`, so it reads naturally there too:

```java
var de = FoodSafety.getDisclosures("de");
```

Hand it the locale your app already resolved. **This library does no i18n**: it will not sniff, negotiate, or quietly fall back — an unknown locale throws `IllegalArgumentException`, because a silently wrong language on an allergen panel is worse than a loud failure. Ask `isLocale` first if you are not sure.

## Keys, not codes

A product row stores `WHEAT` — not `A1`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template. The key never changes meaning.

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, but only 12 are selectable. The law requires naming the specific grain or nut, so you store `WHEAT` or `HAZELNUTS` and render the group declaration above it.

```kotlin
val selected = setOf("WHEAT", "MILK")
de.allergens.filter { it.key in selected }.groupBy { it.group }
// CEREALS → 'Enthält Getreide und glutenhaltige Erzeugnisse', members: [Weizen]
// MILK    → 'Enthält Milch und Milcherzeugnisse (einschließlich Laktose)'
```

## Icons

15 glyphs, one per statutory allergen group, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means.

Every shape paints with `currentColor`, so a glyph inherits the surrounding text colour and follows a light/dark theme with no second asset.

```kotlin
val glyph = FoodSafety.getIcon(wheat.icon)
glyph.viewBox                  // "0 0 24 24"
glyph.nodes.first().attributes // {fill=currentColor, d=…}

FoodSafety.iconToSvg(wheat.icon, size = 16, cssClass = "allergen-icon")
```

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it — someone using a screen reader, or who simply does not recognise the glyph, must still get the declaration.

So they are decorative by default: `iconToSvg` emits `aria-hidden="true"` unless you pass a `title`.

## API

| | |
| --- | --- |
| `FoodSafety.getDisclosures(locale)` | every allergen and declaration for a locale |
| `FoodSafety.getIcon(name)` | a glyph as `Icon(viewBox, nodes)` |
| `FoodSafety.iconToSvg(name, …)` | a glyph as an `<svg>` string |
| `FoodSafety.locales` | the six supported locales |
| `allergenKeys` · `declarationKeys` · `iconNames` | the vocabularies |
| `isLocale` · `isAllergenKey` · `isDeclarationKey` | guards for untrusted input |
| `codeScheme` · `fallbackLocale` | `"MENUELLA"` · `"en"` |

## Languages

German, English, French, Italian, Spanish and Turkish — every key complete in every one. No partial locales, so there is no fallback to reason about at render time.

## Same data, other ecosystems

One binding of a shared dataset — identical vocabulary, keys and icons, released from one tag:

| | |
| --- | --- |
| Maven Central | `com.menuella:food-safety` |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |
| PyPI | [`menuella-food-safety`](https://pypi.org/project/menuella-food-safety/) |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and a set of declarations commonly required alongside them. **Which disclosures a given business must make, and how, is a matter for that business and its jurisdiction.**

## License

MIT — use it in your own products, with or without Menuella.
