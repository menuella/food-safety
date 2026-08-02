# Contributing to @menuella/food-safety

Thanks for considering a contribution. This dataset is for **everyone** who works with restaurant menu compliance, so PRs from developers, translators, food-safety experts, legal practitioners, and chefs are all welcome.

---

## Quick contributions

### 🌐 Add or fix a translation

Open any file under [`data/`](data/), find the entry you want to add a language to, and add the key. Example — adding Portuguese to an allergen:

```diff
  "name": {
    "de": "Roggen",
    "en": "Rye",
+   "pt": "Centeio",
    ...
```

Then update the same key across **all** entries in that file (consistency matters more than completeness for a single language pass).

### 🔤 Add a new language

Same as above — just be willing to translate **all** entries in that file before merging. Partial language coverage gets confusing for consumers.

### 🐛 Fix a typo or description

Open a PR with the change. Bonus points if you include a screenshot of the source regulation.

---

## Bigger contributions

### ➕ Add a new disclosure module

Steps:

1. **Open an issue first** to discuss scope. We want to keep each module narrowly defined.
2. Add `data/<module>/<scope>.json` with all entries.
3. Add `schemas/<module>.schema.json` (JSON Schema draft-07).
4. Add a row to the table in [`README.md`](README.md).
5. Add legal citations to [`docs/legal-references.md`](docs/legal-references.md).
6. Add an entry to [`docs/changelog.md`](changelog.md).

### 🌍 Extend the standard for a region

Menuella Declarations are deliberately **region-independent** — there are no per-country data files, and adding a country does not mean adding a vocabulary. A region is supported as soon as its labels exist under `data/translations/`.

If a region genuinely cannot be served by the current vocabulary — a declaration with no equivalent key — open an issue describing the gap and citing the requirement. Adding a key changes the shared standard for everyone, so it is deliberate rather than automatic. See [`regions.md`](docs/regions.md).

### 🧪 Add or improve a JSON Schema

PRs that strengthen validation are very welcome. Keep schemas at draft-07 for tooling compatibility.

---

## What we will NOT accept

❌ Disclosures for **packaged retail products** (this dataset is restaurant-menu scope only)
❌ Manufacturer-specific labeling rules
❌ Runtime code or servers (those belong in [`menuella/food-safety-js`](https://github.com/menuella/food-safety-js) and others)
❌ Renaming or reusing an existing `key` — keys are stable identifiers, that is the whole point of them
❌ Re-introducing national numbering (`A6`, `11`) as an identifier; it is a rendering convention and belongs in your display layer
❌ Preference, lifestyle or taste vocabularies (vegan, halal, spiciness) — real, but not *safety*; they belong in a menu-attributes dataset
❌ Entries without a primary-source citation when claiming mandatory status

---

## Style guide

### JSON

- **2-space indentation**
- **`de` and `en` are mandatory** in every translation file (fallback languages)
- Structural files carry **no language**; translation files carry **no structure**
- Translation files are **objects keyed by the structural key**, not arrays — a lookup should be `labels[key]`
- Keys are `SCREAMING_SNAKE_CASE`; `canonicalKey` values are `lower_snake_case`; field names are camelCase
- Use straight ASCII quotes in descriptions where possible (`"don't"` not `"don't"`)
- Trailing newlines on every file (`\n`)

### Language codes

ISO 639-1 two-letter codes only (`de`, `en`, not `de-DE` or `eng`).

### Tone of descriptions

- Customer-facing: clear, neutral, non-marketing
- Avoid scare language for warnings — describe the risk, let the consumer decide

---

## Reviewing PRs

Maintainers should verify:

1. Schema validates (`npx ajv validate -s schemas/allergen.schema.json -d data/allergens.json`)
2. Legal citation present for mandatory claims
3. Every key in a translation file exists in the structural file (no orphans)
4. No key renamed or reused
5. Changelog entry for `MINOR` / `MAJOR` changes

---

## Code of conduct

Be kind. We're building reference data restaurants will rely on — disagree on substance, not on people.

---

## License

By contributing, you agree your contribution is licensed under [MIT](LICENSE) — the same as the rest of the dataset.

## Working on the dataset

```bash
npm install        # ajv, for schema validation — no runtime dependencies
npm run generate   # rebuild bundles/, index.js and index.d.ts from the sources
npm run verify     # schemas, key integrity, icons, codes, generated-in-sync
npm test           # runtime contract: immutability, guards, error codes
npm run check      # both
```

Hand-maintained sources are `data/allergens.json`, `data/declarations.json`,
`data/codes.json` and everything under `data/translations/`. **Everything else is generated** — `data/bundles/`,
`index.js` and `index.d.ts` — so edit a source, run `npm run generate`, and
commit the result. `npm run verify` fails if you forget.

All of it runs on every push and pull request, and again before publish.

Releases are automatic: tag a version and CI publishes to npm with provenance.

---
