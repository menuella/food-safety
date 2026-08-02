# Rendering disclosures

How to turn stored keys into what a guest reads. The examples are JavaScript;
the same shapes exist in the [.NET](https://www.nuget.org/packages/Menuella.FoodSafety)
and [Dart](https://pub.dev/packages/menuella_food_safety) bindings.

## Rendering — one call

Hand it the locale your app already resolved. That's the whole API:

```ts
import { getDisclosures } from '@menuella/food-safety'
import { useLocale } from 'next-intl'

const { allergens, declarations } = getDisclosures(useLocale())

allergens[0].name         // "Roggen"
allergens[0].declaration  // "Enthält Getreide und glutenhaltige Erzeugnisse"
allergens[0].icon         // "cereals"  → icons/cereals.svg
```

Astro is the same — `getDisclosures(Astro.currentLocale)`. It is **synchronous**:
no `await`, no loading state, no dynamic import for your bundler to reason about.
Structure, label and icon arrive on one object, so there is no lookup table and
no `GROUP_ICON` map in your app.

The returned object is **deeply frozen**. Bundles are shared singletons, so one
consumer mutating a bundle would corrupt the dataset for every other caller in
the process — on safety data that is not a risk worth carrying. Freezing happens
on first access, which keeps the locale data tree-shakeable for consumers that
never call this.

**It does no i18n.** No browser sniffing, no negotiation, no silent fallback —
guessing the language of a legal declaration is worse than failing loudly. An
unsupported locale throws and names the ones that exist. Want a fallback? That's
your policy, in one line:

```ts
getDisclosures(LOCALES.includes(locale) ? locale : 'en')
```

### Composing — take only what you need

The package **renders nothing**. Every entry is a plain object, so you decide
what appears: icon only, label only, label plus description, codes on or off.

```ts
const { allergens, declarations } = getDisclosures(locale)

// icon only — a compact chip row
allergens.map((a) => `icons/${a.icon}.svg`)

// label only
allergens.map((a) => a.name)                    // "Weizen"

// label + description — a tooltip or expandable row
allergens.map((a) => [a.name, a.description])

// only what this dish declares
allergens.filter((a) => dish.allergens.includes(a.key))

// warnings before the rest
declarations.filter((d) => d.category === 'WARNING')
```

Codes are a separate import, so a surface that never prints a legend never
carries them:

```ts
import codes from '@menuella/food-safety/data/codes.json'

codes.allergens['WHEAT']       // "A6"  — letters for allergens
codes.declarations['SWEETENERS'] // "12"  — numbers for declarations
```

**The one rule that is not yours to compose:** `declaration` is the legal group
sentence, so render it **once per group** with the specific members beneath it —
not once per member. `group` and `isMember` exist to make that grouping trivial:

```ts
const byGroup = new Map<string, Allergen[]>()
for (const a of allergens) byGroup.set(a.group, [...(byGroup.get(a.group) ?? []), a])

// → "Enthält Getreide und glutenhaltige Erzeugnisse — Weizen, Gerste"
[...byGroup.values()].map((m) => `${m[0].declaration} — ${m.map((x) => x.name).join(', ')}`)
```

If you show an icon **without** its label, give it the label as an accessible
name — an allergen glyph alone is not a disclosure.

### Shipping only one language

`getDisclosures` carries all six locales — 7.7 kB gzipped, and switching is
instant. If a surface only ever renders one language (an SSR storefront where
the locale is fixed per request), import that bundle directly for **1.8 kB**:

```ts
import type { Disclosures } from '@menuella/food-safety'
import data from '@menuella/food-safety/bundles/de.json'

const { allergens } = data as Disclosures
```

Both read the same generated files. Importing only the type guards costs
**652 B** — the locale data tree-shakes away entirely.

Every bundle also carries `fallbacks`, listing any field served from `en`, so a
fallback is inspectable rather than silent. Today that array is empty for all six.

---

## Types

```ts
import {
  ALLERGEN_KEYS, isAllergenKey,
  type AllergenKey, type Disclosures, type IconName,
} from '@menuella/food-safety'

isAllergenKey('WHEAT')  // true
isAllergenKey('A6')     // false — retired codes are not keys
```

The key unions are **generated from the data**, so a type can't drift from the dataset. `isAllergenKey` is the quick way to find stored rows that still hold old codes.

---

## Icons

15 solid glyphs in `icons/`, one per allergen group plus one for declarations. Named after the **group**, not after what they depict — `sulphites.svg`, not `wine.svg` — so a redraw never changes the contract. Each entry's `icon` field names its file.

24×24, `fill="currentColor"`, no stroke: they take the colour of whatever they sit in — which is why they follow a light/dark theme with no prop, no second asset and no duplicated palette. An `<img>` cannot do that.

### Rendering them

`@menuella/food-safety/icons` is a **separate entry point**, so consumers that only want the vocabulary never download the path data. Two shapes, because consumers genuinely differ — and neither puts a framework in this package's dependency list:

```js
import { getIcon, getIconSvg } from "@menuella/food-safety/icons"
```

**React, Svelte, Vue** — real elements, no `innerHTML`:

```jsx
const { viewBox, nodes } = getIcon(allergen.icon)

<svg viewBox={viewBox} className="h-4 w-4" aria-hidden focusable="false">
  {nodes.map(([Tag, attrs], i) => <Tag key={i} {...attrs} />)}
</svg>
```

**Astro, e-mail, PDF** — anything that interpolates markup:

```astro
<Fragment set:html={getIconSvg(allergen.icon, { size: 16, className: "h-4 w-4" })} />
```

`getIcon` returns `{ viewBox, nodes }`, where each node is `[tag, attributes]` in React attribute spelling (`fillRule`). `getIconSvg` builds the string from the same data and hyphenates on the way out.

### These glyphs carry legal meaning

An icon means *"contains wheat"*. Render it **alongside** the declaration text, never instead of it — a customer using a screen reader, or one who simply does not recognise the glyph, must still get the declaration.

So they are decorative by default: `getIconSvg` emits `aria-hidden="true" focusable="false"` unless you pass a `title`, which switches it to `role="img"` with a `<title>`. Reach for `title` only when the glyph stands alone, which on a menu it should not.

---
