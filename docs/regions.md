# Supported regions

| Country | Allergens | Menuella Declarations |
|---|---|---|
| 🇩🇪 Germany | ✅ | ✅ |
| 🇦🇹 Austria | ✅ | ✅ |
| 🇫🇷 France | ✅ | ✅ |
| 🇪🇸 Spain | ✅ | ✅ |
| 🇮🇹 Italy | ✅ | ✅ |
| 🇳🇱 Netherlands | ✅ | ✅ |
| 🇵🇱 Poland | ✅ | ✅ |
| 🇮🇪 Ireland | ✅ | ✅ |
| 🇨🇭 Switzerland | ✅ | ✅ |
| 🇬🇧 United Kingdom | ✅ | ✅ |

---

## What Menuella Declarations are

**Menuella Declarations are Menuella's standardized menu disclosure vocabulary and rendering system.** They provide a consistent set of declaration keys and display codes for restaurant menus across supported regions.

The declaration set is designed for **portability and consistency**. It is **not** intended to represent each country's official legal terminology.

What that gives you:

- **One vocabulary everywhere.** A menu in Vienna and a menu in Lyon use the same keys. No per-country branching in your code.
- **A stable API.** `WHEAT` and `NITRITE_CURING_SALT` mean the same thing in every region and every release.
- **Room to grow.** Country-specific legal mappings can be added later, internally, without changing these keys.

## What they are not

Menuella Declarations are **not an official legal standard** in any country, and this package is **not legal advice**.

Food-information law is national in its detail. Which declarations a menu must carry, and the exact wording required, differ between countries — and in some cases between states within one country. Menuella Declarations give you a consistent way to *record and render* disclosures; they do not certify that a given menu satisfies a given jurisdiction.

**You remain responsible for compliance where you operate.** Where a regulator requires particular wording, render your own text against these keys — the keys are the stable part, the wording is yours.

## Where the vocabulary came from

The allergen set follows **EU Regulation 1169/2011 Annex II**, which is harmonized across the EU and retained in the UK, so it is common ground everywhere in the table above.

The declaration set was **inspired by common German restaurant menu practice**, which is unusually well developed — German menus have carried additive and warning footnotes for decades, so it was the most complete starting point available. It has since been generalized: packaging-only entries were removed as unsuitable for a menu, and the numbering was replaced (see below).

Primary sources are cited in [`legal-references.md`](legal-references.md).

---

## Footnote codes

Menus print a short code next to each declaration. The keys stay the identity; the codes ship separately as a rendering convention:

```ts
import codes from '@menuella/food-safety/data/codes.json'

codes.allergens['WHEAT']      // → "A6"
codes.declarations['SWEETENERS'] // → "12"
```

There is **one scheme**, `MENUELLA`, used in every supported region.

- The **letters** follow long-established EU menu practice, so guests already recognise them.
- The **numbers** are Menuella's own contiguous 1–22. National legends are not standardized — the same number means different things on different menus — so there was no existing numbering worth mirroring.

**Treat a code as a rendering convention, never an identity.** Don't store one. When *reading* someone else's menu, resolve it against that menu's own legend first: the number alone is not enough to know what was declared.

### Allergens

| Code | Key | | Code | Key |
|---|---|---|---|---|
| `A` | *(group — `group: CEREALS`)* | | `H` | *(group — `group: TREE_NUTS`)* |
| `A1` | `RYE` | | `H1` | `MACADAMIA` |
| `A2` | `BARLEY` | | `H2` | `ALMONDS` |
| `A3` | `EMMER` | | `H3` | `BRAZIL_NUTS` |
| `A4` | `EINKORN` | | `H4` | `PECANS` |
| `A5` | `SPELT` | | `H5` | `PISTACHIOS` |
| `A6` | `WHEAT` | | `H6` | `WALNUTS` |
| `A7` | `OATS` | | `H7` | `CASHEWS` |
| `A8` | `KHORASAN` | | `H8` | `HAZELNUTS` |
| `B` | `CRUSTACEANS` | | `L` | `CELERY` |
| `C` | `EGGS` | | `M` | `MUSTARD` |
| `D` | `FISH` | | `N` | `SESAME` |
| `E` | `PEANUTS` | | `O` | `SULPHITES` |
| `F` | `SOY` | | `P` | `LUPINS` |
| `G` | `MILK` | | `R` | `MOLLUSCS` |

`A` and `H` are group headings with no key. They are not lawful declarations on their own — the specific cereal or nut must be named. If a source menu declares a bare `A` or `H`, it is under-declaring, and you need the actual recipe to resolve it.

### Declarations

> ⚠️ **The numbers are the volatile part.** This is a contiguous 1–22 in the order a legend is normally read: additives, then beverage declarations, then warnings and product-specific indications. Older German legends ran 1–27 and included packaging-only entries, and **most numbers do not line up** — in a 1–27 legend `11` is sweeteners, here `11` is phosphate. Never carry numbers across from another source; re-resolve through the keys.

| Code | Key | | Code | Key |
|---|---|---|---|---|
| `1` | `COLORING` | | `12` | `SWEETENERS` |
| `2` | `PRESERVATIVES` | | `13` | `PHENYLALANINE` |
| `3` | `ANTIOXIDANTS` | | `14` | `LAXATIVE_WARNING` |
| `4` | `NITRITE_CURING_SALT` | | `15` | `CAFFEINE` |
| `5` | `NITRATE` | | `16` | `QUININE` |
| `6` | `NITRITE_CURING_SALT_AND_NITRATE` | | `17` | `CHILD_ATTENTION_WARNING` |
| `7` | `FLAVOR_ENHANCERS` | | `18` | `MILK_PROTEIN` |
| `8` | `SULPHURED` | | `19` | `SURIMI` |
| `9` | `BLACKENED` | | `20` | `RECONSTITUTED_MEAT` |
| `10` | `WAXED` | | `21` | `RECONSTITUTED_FISH` |
| `11` | `PHOSPHATE` | | `22` | `DEFROSTED` |

Packaging-only declarations — protective atmosphere, iodised salt, cocoa fat glaze, taurine, GMO notes, oxygen colour stabilisation, elevated-caffeine package warnings — have no key and no code. They belong on a package, not a menu.

Validated by [`schemas/code.schema.json`](../schemas/code.schema.json): every key must have a code, and no code may repeat.

---

## Adding a region

Nothing to add, in most cases — the vocabulary is deliberately region-independent, so a new country is supported the moment its labels exist in [`translations/`](../data/translations).

If a region genuinely cannot be served by this vocabulary — a declaration with no equivalent key — open an issue describing the gap and citing the requirement. Adding a key is a change to the shared standard, so it is deliberate rather than automatic. See [`CONTRIBUTING.md`](../CONTRIBUTING.md).
