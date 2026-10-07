# Rendering disclosures

How to turn stored keys into what a guest reads. The examples are JavaScript;
the same shapes exist in the [.NET](https://www.nuget.org/packages/Menuella.FoodSafety)
and [Dart](https://pub.dev/packages/menuella_food_safety) bindings.

## Rendering — pick a locale, resolve the keys

Import the locale your app already resolved, and hand it the keys a product
carries:

```ts
import de from '@menuella/food-safety/locales/de'
import { resolveDisclosures } from '@menuella/food-safety'

const { allergens, declarations, unknown } = resolveDisclosures(de, product.disclosures)

allergens[0].declaration                 // "Enthält Getreide und glutenhaltige Erzeugnisse"
allergens[0].members.map((m) => m.name)  // ["Gerste", "Weizen"]
allergens[0].icon                        // "cereals"  → icons/cereals.svg
```

`resolveDisclosures` applies the one rule that is not yours to compose:
`declaration` is the legal group sentence, so it is stated **once per group**,
with the specific members beneath it — not once per member. Groups and
declarations come back in the dataset's order, not the input's, so the same
product always renders the same way. A key this release does not know — a
retired code, or a key from a newer release — lands in `unknown` rather than
disappearing: on an allergen panel, showing a raw key beats silently showing
less.

### Four entry points, one dataset

| Import | Gives you | Cost (gzip) |
|---|---|---|
| `@menuella/food-safety` | keys, groups, guards, types, `resolveDisclosures` | ~0.7–1.1 kB, no locale data |
| `@menuella/food-safety/locales/<tag>` | one locale, typed and frozen | ~1.8 kB per locale |
| `@menuella/food-safety/load` | `loadDisclosures(tag)` — on demand | ~1.2 kB, then one chunk per locale |
| `@menuella/food-safety/all` | `getDisclosures(tag)` — synchronous | ~33 kB, every locale |

**One fixed locale** (a server render, a page per language): import it
statically, as above. **The locale changes at runtime** in a browser: load it,
and only that locale is downloaded —

```ts
import { loadDisclosures } from '@menuella/food-safety/load'

const disclosures = await loadDisclosures(locale)
```

Each locale is a literal `import()`, so every bundler splits it into a chunk of
its own. **Build scripts, servers, tests**, where size does not matter:

```ts
import { getDisclosures } from '@menuella/food-safety/all'
```

All three return the same object for the same locale. It is **deeply frozen**:
bundles are shared singletons, so one consumer mutating a bundle would corrupt
the dataset for every other caller in the process — on safety data that is not
a risk worth carrying. The types say so too: every field is `readonly`.

**It does no i18n.** No browser sniffing, no negotiation, no silent fallback —
guessing the language of a legal declaration is worse than failing loudly. An
unsupported locale throws (or, from `loadDisclosures`, rejects) with
`code: "ERR_UNSUPPORTED_LOCALE"` and names the locales that exist. Tags are
matched exactly: `pt-BR` is a locale, `pt-br` and `pt` are not. Want a
fallback? That's your policy, in one line:

```ts
import { isLocale } from '@menuella/food-safety'

loadDisclosures(isLocale(locale) ? locale : 'en')
```

### Composing — take only what you need

The package **renders nothing**. Every entry is a plain object, so you decide
what appears: icon only, label only, label plus description, codes on or off.

```ts
const { allergens, declarations } = de

// icon only — a compact chip row
allergens.map((a) => `icons/${a.icon}.svg`)

// label only
allergens.map((a) => a.name)                    // "Weizen"

// label + description — a tooltip or expandable row
allergens.map((a) => [a.name, a.description])

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

If you show an icon **without** its label, give it the label as an accessible
name — an allergen glyph alone is not a disclosure.

Every bundle also carries `fallbacks`, listing any field served from `en`, so a
fallback is inspectable rather than silent. Today that array is empty for every
locale.

### Raw JSON

`@menuella/food-safety/bundles/<tag>.json` is the same data as plain JSON, for
tools that read files rather than import modules. Its shape is `Disclosures`.

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
