# menuella-food-safety

> Open dataset of **restaurant menu allergens and declarations** — 28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote codes, 15 icons, and six languages.

Semantic keys instead of country-specific numbers. **Store the key, render the code — never the other way round.**

Pure Python, **no dependencies**, typed, and the data is read through `importlib.resources` — so it works from a zip import, a container, or a serverless bundle.

```sh
pip install menuella-food-safety
```

## Use it

```python
from menuella_food_safety import get_disclosures

de = get_disclosures("de")

wheat = next(a for a in de.allergens if a.key == "WHEAT")
wheat.name         # 'Weizen'
wheat.declaration  # 'Enthält Getreide und glutenhaltige Erzeugnisse'
wheat.icon         # 'cereals'
```

Hand it the locale your app already resolved. **This package does no i18n**: it will not sniff, negotiate, or quietly fall back — an unknown locale raises `ValueError`, because a silently wrong language on an allergen panel is worse than a loud failure. Ask `is_locale` first if you are not sure.

## Keys, not codes

A product row stores `WHEAT` — not `A1`, not `21`. Footnote codes are a *rendering* of the key, chosen at print time and varying by region and template. The key never changes meaning.

`CEREALS` and `TREE_NUTS` are **groups, not keys**: 14 groups, but only 12 are selectable. The law requires naming the specific grain or nut, so you store `WHEAT` or `HAZELNUTS` and render the group declaration above it.

```python
from collections import defaultdict

selected = {"WHEAT", "MILK"}
by_group = defaultdict(list)
for a in de.allergens:
    if a.key in selected:
        by_group[a.group].append(a)

# CEREALS → 'Enthält Getreide und glutenhaltige Erzeugnisse', members: [Weizen]
# MILK    → 'Enthält Milch und Milcherzeugnisse (einschließlich Laktose)'
```

## Icons

15 glyphs, one per statutory allergen group, named after the **key** rather than the depiction — `sulphites`, not `wine` — so a redraw never changes what a symbol means.

Every shape paints with `currentColor`, so a glyph inherits the surrounding text colour and follows a light/dark theme with no second asset.

```python
from menuella_food_safety import get_icon, icon_to_svg

glyph = get_icon(wheat.icon)
glyph.view_box            # '0 0 24 24'
glyph.nodes[0].tag        # 'path'
glyph.nodes[0].attributes # (('fill', 'currentColor'), ('d', '…'))

icon_to_svg(wheat.icon, size=16, css_class="allergen-icon")
```

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it — someone using a screen reader, or who simply does not recognise the glyph, must still get the declaration.

So they are decorative by default: `icon_to_svg` emits `aria-hidden="true"` unless you pass a `title`.

## Raw dataset

For tooling that wants the JSON rather than resolved objects:

```python
from menuella_food_safety import load_dataset

dataset = load_dataset()   # {"allergens": [...], "declarations": [...],
                           #  "codes": {...}, "icons": {...}}
```

## API

| | |
| --- | --- |
| `get_disclosures(locale)` | every allergen and declaration for a locale |
| `get_icon(name)` | a glyph as `Icon(view_box, nodes)` |
| `icon_to_svg(name, …)` | a glyph as an `<svg>` string |
| `load_dataset()` | the raw JSON, for tooling |
| `LOCALES` | the six supported locales |
| `ALLERGEN_KEYS` · `DECLARATION_KEYS` · `ICON_NAMES` | the vocabularies |
| `is_locale` · `is_allergen_key` · `is_declaration_key` | guards for untrusted input |
| `CODE_SCHEME` · `FALLBACK_LOCALE` | `'MENUELLA'` · `'en'` |

Entries are frozen dataclasses — immutable and hashable, so one caller cannot corrupt the dataset for another.

## Languages

German, English, French, Italian, Spanish and Turkish — every key complete in every one. No partial locales, so there is no fallback to reason about at render time.

## Same data, other ecosystems

One binding of a shared dataset. The vocabulary, the keys and the icons are identical across all of them, released from one tag:

| | |
| --- | --- |
| PyPI | `menuella-food-safety` |
| npm | [`@menuella/food-safety`](https://www.npmjs.com/package/@menuella/food-safety) |
| NuGet | [`Menuella.FoodSafety`](https://www.nuget.org/packages/Menuella.FoodSafety) |
| pub.dev | [`menuella_food_safety`](https://pub.dev/packages/menuella_food_safety) |

## Not legal advice

The dataset encodes the allergen groups of EU Reg. 1169/2011 Annex II and a set of declarations commonly required alongside them. **Which disclosures a given business must make, and how, is a matter for that business and its jurisdiction.** This package gives you correct, complete, translated text to render — it does not decide what you are obliged to render.

## License

MIT — use it in your own products, with or without Menuella.
