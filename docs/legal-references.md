# Legal references

Primary sources behind the vocabulary. **This is not legal advice** — verify with local authorities for your jurisdiction.

These citations record where the vocabulary *came from*. They are not a claim that Menuella Declarations reproduce any country's official legal terminology — see [`regions.md`](regions.md) for what the standard is and is not.

---

## Allergens (`data/allergens.json`)

| Item | Source |
|---|---|
| Mandatory 14 allergens | **Regulation (EU) No 1169/2011** — Annex II, "Substances or products causing allergies or intolerances" |
| Display obligation | Reg. 1169/2011 Art. 9, Art. 21 |
| German implementation | **Lebensmittelinformations-Durchführungsverordnung (LMIDV)** |
| EU consolidated text | https://eur-lex.europa.eu/eli/reg/2011/1169/oj |

**Why 28 keys for 14 groups.** Annex II lists cereals containing gluten and tree nuts as groups, but requires the declaration to name the **specific** cereal or nut — a bare "glutenhaltiges Getreide" or "Schalenfrüchte" is not a lawful declaration, and German food-safety inspectorates (Veterinäramt) enforce this. So those two groups are expanded into their members and are not themselves selectable; they survive as the `group` field with a `declaration` sentence.

**On codes.** German menus commonly print letter codes (`A`–`R`, with cereals as A1–A8 and nuts as H1–H8). These are a **presentation convention**, not defined by Reg. 1169/2011, and they vary between print shops and states. This dataset stores semantic keys and leaves the numbering to the surface that renders the menu.

---

## Menuella Declarations (`data/declarations.json`)

| Item | Source |
|---|---|
| Permitted additives | **Regulation (EC) No 1333/2008** — Food additives |
| Mandatory menu disclosure | **Zusatzstoff-Zulassungsverordnung (ZZulV)** §9 + Anlage 9, **Lebensmittel-Kennzeichnungsverordnung (LMKV/LMZDV)** |
| Caffeine threshold (>150 mg/L) | Reg. 1169/2011 Annex III §4 |
| Sweeteners disclosure | Reg. 1333/2008 + Reg. 1169/2011 |
| Colourings — child attention warning | **Reg. (EC) No 1333/2008** Annex V (Southampton six) |
| Reconstituted meat / fish | Reg. 1169/2011 Annex VI Part A §7 |
| Defrosted | Reg. 1169/2011 Annex VI Part A §2 |

**Scope.** Broader than additives alone: additive declarations plus beverage declarations, mandatory warnings, and other product-specific indications. The `category` field distinguishes them. The set was inspired by common German restaurant menu practice — the most developed starting point available — then generalized for use across regions.

**Excluded by design.** Protective atmosphere, iodised salt, cocoa fat glaze, taurine, GMO notes, oxygen colour stabilisation and elevated-caffeine package warnings are **packaging** declarations under Reg. 1169/2011 Annex III / Annex VI. They are not part of a restaurant menu legend and are deliberately absent.

**On numbering.** Menus print numbers next to these declarations. National numbering is **not standardized** between print shops or states, so Menuella defines its own contiguous scheme rather than mirroring one — see [`regions.md`](regions.md). Numbers are a render-time projection of the semantic keys and are never stored.

---

---

## How to add a new module

When adding a new disclosure module, document:

1. **Primary regulation** (EU or national)
2. **Article / annex** reference
3. **When mandatory vs. voluntary**
4. **How it fits the portable standard** (in [`regions.md`](regions.md))

PRs without legal citations will not be merged for items claiming mandatory status.
