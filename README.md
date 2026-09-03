# @menuella/food-safety

> Open dataset of **restaurant menu disclosures** — the 14 EU allergen groups and **Menuella Declarations**, with codes, icons and labels in 6 languages, keyed by stable semantic keys.

[![Verify](https://github.com/menuella/food-safety/actions/workflows/verify.yml/badge.svg)](https://github.com/menuella/food-safety/actions/workflows/verify.yml)
[![npm](https://img.shields.io/npm/v/@menuella/food-safety.svg)](https://www.npmjs.com/package/@menuella/food-safety)
[![NuGet](https://img.shields.io/nuget/v/Menuella.FoodSafety.svg)](https://www.nuget.org/packages/Menuella.FoodSafety)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Store the key. Render the code. Never the reverse.**

## Install

One dataset, one version, released from one tag.

| | |
|---|---|
| **npm** | `npm i @menuella/food-safety` |
| **NuGet** | `dotnet add package Menuella.FoodSafety` |
| **Dart** | `dart pub add menuella_food_safety` |
| **Python** | `pip install menuella-food-safety` |
| **PHP** | `composer require menuella/food-safety` |
| **Rust** | `cargo add menuella-food-safety` |
| **Ruby** | `bundle add menuella-food_safety` |
| **Go** | `go get github.com/menuella/food-safety/packages/go` |
| **Swift** | `.package(url: "https://github.com/menuella/food-safety", from: "1.3.1")` |
| **Gradle** | `implementation("com.menuella:food-safety:1.3.1")` |

```js
import { getDisclosures } from "@menuella/food-safety"

const { allergens } = getDisclosures("de")
allergens.find((a) => a.key === "WHEAT").declaration
// "Enthält Getreide und glutenhaltige Erzeugnisse"
```

Hand it the locale your app already resolved — this package does no i18n of its own. See **[docs/rendering.md](docs/rendering.md)** for grouping, icons, codes and the type surface.

## The Menuella standard

Five pieces, one vocabulary, every region:

| | |
|---|---|
| **Menuella Allergen Keys** | 28 semantic keys covering the 14 EU allergen groups |
| **Menuella Declarations** | 22 keys for additives, beverage declarations, warnings and product indications |
| **Menuella Codes** | the short codes printed in a menu legend — `WHEAT` → `A6` |
| **Menuella Icons** | 15 solid glyphs, one per group |
| **Menuella Translations** | localized labels in 6 languages |

**Menuella Declarations are a standardized restaurant menu disclosure vocabulary developed by Menuella for consistent rendering across applications and regions.** They are built for portability, not to reproduce any country's official legal terminology — see [`docs/regions.md`](docs/regions.md).

You never work with country-specific terminology. A menu in Vienna, Lyon or Dublin uses the same keys, so there is no per-country branching in your code and no per-country churn in this package. Legal mappings can be layered on internally later without any of these keys changing.

---

## Keys, not codes

Every entry is identified by a **stable semantic key** — `WHEAT`, `SESAME`, `NITRITE_CURING_SALT` — and never by a number or letter.

Menus print codes like `A6` for wheat or `11` for sweeteners. Those codes are **not standardized** between print shops, or even between states, so the same `11` means different things on different menus. They are a *rendering convention*, not an identity. Storing them is how disclosure data rots.

So this dataset stores the meaning as the identity, and ships the numbering **separately** as what it is — a rendering convention. One scheme, usable in any region:

```ts
import codes from '@menuella/food-safety/data/codes.json'

codes.allergens['WHEAT']      // → "A6"
codes.declarations['SWEETENERS'] // → "12"
```

The letters follow long-established EU menu practice so guests recognise them; the numbers are Menuella's own contiguous 1–22, because national legends are not standardized and there was nothing worth mirroring. You get numbers when you need to print a legend, without the numbers ever becoming an identity. A key is legible in a database dump, survives a change of print shop, and is what an AI agent or Google Business Profile actually understands.

**Store keys. Render codes. Never the reverse.** Full tables and the caveats in [`docs/regions.md`](docs/regions.md).

---

## What's included

| Module | Structural file | Items | Source |
|---|---|---|---|
| Allergens | [`data/allergens.json`](data/allergens.json) | 28 keys / 14 groups | EU Reg. 1169/2011 Annex II (LMIV) |
| Menuella Declarations | [`data/declarations.json`](data/declarations.json) | 22 | Menuella standard |

### Allergens — 28 keys, not 14

The law names 14 groups, but two of them may never be declared as a group. LMIV (and the Veterinäramt) require naming the **specific cereal** and the **specific tree nut** — "glutenhaltiges Getreide" and "Schalenfrüchte" are not lawful declarations on their own. So those two groups are expanded into their members and the group itself is not selectable:

- **CEREALS** → `RYE` `BARLEY` `EMMER` `EINKORN` `SPELT` `WHEAT` `OATS` `KHORASAN`
- **TREE_NUTS** → `MACADAMIA` `ALMONDS` `BRAZIL_NUTS` `PECANS` `PISTACHIOS` `WALNUTS` `CASHEWS` `HAZELNUTS`
- The other 12 groups are one key each: `CRUSTACEANS` `EGGS` `FISH` `PEANUTS` `SOY` `MILK` `CELERY` `MUSTARD` `SESAME` `SULPHITES` `LUPINS` `MOLLUSCS`

`group` and `isMember` carry that structure, and `declaration` is the group sentence — **render it once per group**, with the specific members beneath:

> **Enthält Getreide und glutenhaltige Erzeugnisse** — Weizen, Gerste

### Menuella Declarations

**Menuella Declarations are Menuella's standardized menu disclosure vocabulary and rendering system** — a consistent set of declaration keys and display codes for restaurant menus across every supported region. They cover additive declarations plus beverage declarations, mandatory warnings and other product-specific indications; `category` tells them apart: `ADDITIVE`, `BEVERAGE`, `WARNING`, `PRODUCT`.

The set is designed for **portability and consistency**, and is **not** intended to represent any country's official legal terminology. One vocabulary in Vienna, Lyon and Dublin means no per-country branching in your code — and no per-country churn in this package.

The vocabulary was *inspired by* common German restaurant menu practice, which is unusually well developed, then generalized: packaging-only entries were dropped as unsuitable for a menu, and the numbering replaced. See [`docs/regions.md`](docs/regions.md).

> Branded end to end: the file is `declarations.json`, the type is `DeclarationKey`, the bundle field is `declarations`. "Additives" is the narrower, everyday word — these keys also cover beverage and product notes that are not additives at all.

Tag dish "Pizza Sucuk" with [sucuk, cheddar, weizenmehl]
   ↓
allergens = MILK (cheddar) + WHEAT (flour)  = ["MILK", "WHEAT"]
declarations = NITRITE_CURING_SALT (sucuk)  = ["NITRITE_CURING_SALT"]
```

---

## Languages

| Code | Language | Allergens | Additives |
|---|---|---|---|
| `de` | German | 28 ✅ + declarations | 22 ✅ |
| `en` | English | 28 ✅ + declarations | 22 ✅ |
| `es` | Spanish | 28 ✅ + declarations | 22 ✅ |
| `fr` | French | 28 ✅ + declarations | 22 ✅ |
| `it` | Italian | 28 ✅ + declarations | 22 ✅ |
| `tr` | Turkish | 28 ✅ + declarations | 22 ✅ |

Every language is complete: all 28 allergens and 22 declarations carry a name, description and — for allergens — the group declaration sentence.

Missing a language you need? **Open a PR.** Adding one = one new file under `data/translations/<module>/<lang>.json`.

---

## What's NOT in here (by design)

- ❌ Codes as identifiers — they ship in `data/codes/` for rendering, but are never a key
- ❌ **Ingredient → key mappings.** The keys are designed so a dish's disclosures *can* be rolled up from its ingredients, but the mapping itself is curation, not vocabulary — it lives in [Menuella](https://www.menuella.com), or you build your own.
- ❌ Preference, lifestyle and taste vocabularies (vegan, halal, spiciness) — real menu attributes, but not *safety* disclosures
- ❌ Nutrition values and country-of-origin — a different obligation with a different shape; out of scope here
- ❌ Industrial / packaging labeling rules (this is *menu* scope only)
- ❌ Manufacturer-specific labeling
- ❌ Runtime code, parsers, or servers — companion repos planned:
  - `menuella/food-safety-js` — TS/JS helpers (formatters, validators, rollup)
  - `menuella/food-safety-detect` — AI-assisted detection from product name + description

---

## Versioning

Conservative SemVer:

- **MAJOR** — breaking schema change (avoided where possible)
- **MINOR** — new language, new module, new entries
- **PATCH** — translation fixes, typo fixes, description clarifications

Keys (`WHEAT`, `NITRITE_CURING_SALT`) and `canonicalKey` values are **stable identifiers** — they will never be renamed or reused. That guarantee is exactly why they replaced the codes.

Pin to a major version in production:

```jsonc
{ "dependencies": { "@menuella/food-safety": "^0" } }
```

See [`CHANGELOG.md`](CHANGELOG.md).

---

## Documentation

| | |
|---|---|
| [docs/rendering.md](docs/rendering.md) | turning keys into what a guest reads — grouping, icons, codes, types |
| [docs/data-shapes.md](docs/data-shapes.md) | the on-disk format, for editing the dataset or writing a binding |
| [docs/legal-references.md](docs/legal-references.md) | the source regulations behind every entry |
| [docs/regions.md](docs/regions.md) | how the codes relate to regional conventions |
| [CONTRIBUTING.md](CONTRIBUTING.md) | proposing a change, and validating one |

## Legal disclaimer

This dataset is provided **for informational purposes**. We cite source regulations in [`docs/legal-references.md`](docs/legal-references.md) and aim for accuracy, but **you remain responsible for compliance** with the laws of your jurisdiction. This dataset is **not** legal advice.

---

## Contributing

Translations, corrections and new languages are welcome.

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to propose a change, and what a PR needs
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) — how we work together
- [`SECURITY.md`](SECURITY.md) — reporting a vulnerability privately
- [`docs/regions.md`](docs/regions.md) — what Menuella Declarations are, and are not
- [`docs/legal-references.md`](docs/legal-references.md) — primary sources

Anything touching allergens or legal wording needs a citation. People with allergies read what we publish.

---

## License

[MIT](LICENSE) © Menuella

Use it, fork it, embed it in commercial products. MIT asks one thing in return:
that the copyright and permission notice travels with substantial portions of
the dataset.

- **Installing from npm** — nothing to do. `LICENSE` ships inside the package.
- **Vendoring files into your own repo** — copy `LICENSE` alongside them, or
  credit `@menuella/food-safety` in your own notices.
- **Inlining the icons** — SVG comments get stripped by optimizers, so there is
  no per-file banner to preserve. The root `LICENSE` covers them.

---

## Links

- 🔎 Explorer — [menuella.com/food-safety](https://www.menuella.com/food-safety)
- 📦 [npm](https://www.npmjs.com/package/@menuella/food-safety) · [NuGet](https://www.nuget.org/packages/Menuella.FoodSafety) · [pub.dev](https://pub.dev/packages/menuella_food_safety) · [PyPI](https://pypi.org/project/menuella-food-safety/) · [Packagist](https://packagist.org/packages/menuella/food-safety) · [crates.io](https://crates.io/crates/menuella-food-safety) · [RubyGems](https://rubygems.org/gems/menuella-food_safety) · [pkg.go.dev](https://pkg.go.dev/github.com/menuella/food-safety/packages/go)
- 🧑‍💻 [github.com/menuella/food-safety](https://github.com/menuella/food-safety)
