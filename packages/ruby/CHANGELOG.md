# Changelog

All notable changes to this dataset will be documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [SemVer](https://semver.org/).

Pin to a major version in production:

```jsonc
{ "dependencies": { "@menuella/food-safety": "^0" } }
```

---

## [1.3.0]

### Added

- **Ruby gem** — [`menuella-food_safety`](https://rubygems.org/gems/menuella-food_safety).
  - `disclosures`, `codes`, `icon`, `icon_to_svg`, `dataset`, plus `locales`, `allergen_keys`, `declaration_keys`, `icon_names`, `code_scheme` and the `locale?` / `allergen_key?` / `declaration_key?` guards. `UnsupportedLocaleError` and `UnknownIconError` both descend from `Menuella::FoodSafety::Error`, so a caller can rescue the whole surface at once.
  - The gem ships the canonical JSON and reads it at runtime — `json` is a default gem, so there is **no runtime dependency** and nothing to generate.
  - Value objects are `Data`, and everything returned is **frozen**. The dataset is shared state; a caller able to push onto an allergen list would be editing every other caller's copy in the same process.
  - Named `menuella-food_safety`, not `menuella-food-safety`: in Ruby a dash separates the namespace and an underscore joins words inside it, so this is `Menuella::FoodSafety`. The all-dash form would claim to be `Menuella::Food::Safety`.
  - Published by Trusted Publishing, so no RubyGems API key exists anywhere.

---

## [1.2.0]

### Added

- **Rust crate** — [`menuella-food-safety`](https://crates.io/crates/menuella-food-safety).
  - `disclosures`, `icon`, `icon_to_svg`, `allergen_code`, `declaration_code`, the `LOCALES` / `ALLERGEN_KEYS` / `DECLARATION_KEYS` / `ICON_NAMES` / `CODES` tables, and the `is_locale` / `is_allergen_key` / `is_declaration_key` guards. Two error types, `UnsupportedLocale` and `UnknownIcon`.
  - The dataset is **generated Rust source**, not JSON read at runtime: the standard library has no JSON parser, so shipping the data as `&'static str` keeps the crate at **zero dependencies** where the alternative was forcing `serde_json` on every consumer. Nothing is parsed at startup and nothing is allocated to read it.
  - Because it is all `const`, `disclosures_const` binds a whole bundle at compile time.
  - `serde` is an **opt-in feature** adding `Serialize`. `Deserialize` is deliberately absent — every field borrows from the binary's static data, so there is nothing to deserialize into.
  - Published by Trusted Publishing, so no crates.io token exists anywhere.

- **Go module support** — `github.com/menuella/food-safety/packages/go`.
  - `GetDisclosures`, `GetIcon`, `IconToSVG`, `GetCodes`, `LoadDataset`, plus `Locales`, `AllergenKeys`, `DeclarationKeys`, `IconNames`, `CodeScheme` and the `IsLocale` / `IsAllergenKey` / `IsDeclarationKey` guards. Errors wrap `ErrUnsupportedLocale` and `ErrUnknownIcon`, so callers can branch with `errors.Is`.
  - The dataset is embedded with `//go:embed`, so the binary is self-contained and there is nothing to find on disk at runtime. `encoding/json` is in the standard library, so the module has **no dependencies**.
  - Like Swift, there is no registry: the git tag is the release.
  - Because the module is **nested**, the Go proxy only sees a tag carrying its directory prefix — `packages/go/v1.2.0`, not `v1.2.0`. A workflow derives that tag from the plain one on push, so it cannot be forgotten; without it, six registries would publish and Go would silently stay behind.

### Changed

- **Maven Central now publishes automatically** rather than holding each upload for a manual release. The earlier setting reasoned that Central has no unpublish — but pub.dev and NuGet cannot unpublish either and publish automatically, so the gate was inconsistent rather than principled, and in practice it was a step that got skipped. The deliberate act is the tag; tests and a tag/version check both run before the upload.

---

## [1.1.0]

### Added

- **Swift Package Manager support** — the same dataset for iOS, macOS, tvOS, watchOS and visionOS.
  - `FoodSafety.disclosures(locale:)`, `codes()`, `icon(named:)`, `iconToSVG(named:size:cssClass:title:)`, plus `locales`, `allergenKeys()`, `declarationKeys()`, `iconNames()` and the `isLocale` / `isAllergenKey` / `isDeclarationKey` guards.
  - Swift 6 language mode, `Sendable` throughout, **no dependencies**.
  - Reads the canonical JSON from its resource bundle: `JSONDecoder` is in Foundation, so there is nothing to generate.
  - There is no registry to publish to — SwiftPM resolves straight from the git tag, so `v1.1.0` is the release.

### Changed

- `Package.swift` sits at the **repository root**, because SwiftPM resolves the manifest from there and has no monorepo support — the same constraint Packagist imposes. Its target paths point into `packages/swift/`.

---

## [1.0.1]

### Added

- **`menuella/food-safety` on Packagist** — the same dataset for PHP.
  - `FoodSafety::getDisclosures($locale)`, `getIcon($name)`, `iconToSvg($name, …)`, `loadDataset()`, plus `LOCALES`, `allergenKeys()`, `declarationKeys()`, `iconNames()`, `codeScheme()` and the `isLocale` / `isAllergenKey` / `isDeclarationKey` guards.
  - PHP 8.2+, **no dependencies** beyond `ext-json`, and every returned object is `readonly` — the dataset is a process-wide singleton, so one caller must not be able to corrupt it for another.
  - Reads the canonical JSON at runtime: `json_decode` is in core, so there is nothing to generate and nothing to depend on.

### Changed

- `composer.json` sits at the **repository root**, because Packagist reads it from there and has no monorepo support. Its PSR-4 autoload points into `packages/php/src/`.
- A `.gitattributes` marks the other bindings `export-ignore`, so `composer require` downloads the PHP package rather than an archive of all six. This affects git archives only — every other registry publishes an artifact built from a checkout.

---

## [1.0.0]

The vocabulary is stable, and this release commits to it.

Nothing changes in the data or the APIs — 0.3.6 and 1.0.0 are the same dataset.
What changes is the promise: from here, **keys, exports and data shapes will not
break without a major version**.

That is a promise worth making because the hard part is not ours to change. The
28 allergen keys follow Annex II of EU Reg. 1169/2011, the 22 declarations are a
settled vocabulary, and both are addressed by semantic keys rather than
region-specific codes — so new languages, new icons and new declarations are all
additive.

### What stability covers

- Allergen and declaration **keys**, and the group each allergen belongs to
- The **shape** of what each binding returns
- Every binding's **public API**
- The `MENUELLA` **code scheme**

New locales, new declarations, corrected translations and redrawn icons remain
minor or patch changes. A key is never renamed or repurposed; if one is ever
retired, its guard starts returning false and the key stays reserved.

---

## [0.3.6]

### Changed

- Repository presentation only — no change to the dataset, the APIs or any generated artifact. 0.3.5 and 0.3.6 are the same vocabulary.

---

## [0.3.5]

### Added

- **`com.menuella:food-safety` on Maven Central** — the same dataset for Kotlin, Java and Android.
  - `FoodSafety.getDisclosures(locale)`, `getIcon(name)`, `iconToSvg(name, …)`, plus `locales`, `allergenKeys`, `declarationKeys`, `iconNames`, `codeScheme` and the `isLocale` / `isAllergenKey` / `isDeclarationKey` guards. Everything is `@JvmStatic`, so it reads naturally from Java.
  - JVM 17+, `explicitApi()` strict, and **nothing beyond `kotlin-stdlib`**.
  - Ships **generated Kotlin source** rather than JSON read at runtime. The JVM has no JSON parser in its standard library, so reading the data at runtime would have meant taking a real dependency on one — and it also means the package works on Android and in a Native Image with no reflection or resource configuration.
  - One generated file **per locale**: a JVM method body is capped at 64 KB of bytecode, and six locales of ~300 string constants in one static initializer would sail past it.
  - Gradle Kotlin DSL with `maven-publish`, `signing` (in-memory PGP keys, so no keyring is written to a runner) and GradleUp `nmcp` for the Central Portal.
  - `publicationType` is `USER_MANAGED`: the upload is validated but held for a human to release, because **Maven Central has no unpublish**.

### Changed

- `npm run verify` now covers all five registries for version parity, and diffs every generated Kotlin file against its source.

---

## [0.3.4]

### Added

- **`menuella-food-safety` on PyPI** — the same dataset for Python.
  - `get_disclosures(locale)`, `get_icon(name)`, `icon_to_svg(name, …)`, plus `LOCALES`, `ALLERGEN_KEYS`, `DECLARATION_KEYS`, `ICON_NAMES`, `CODE_SCHEME` and the `is_locale` / `is_allergen_key` / `is_declaration_key` guards. `load_dataset()` returns the raw JSON for tooling.
  - **No dependencies**, typed (`py.typed`), Python 3.10+.
  - Ships the canonical JSON and reads it through `importlib.resources` — no generated source, because unlike Dart there is no Python platform without a resource loader, so a generator would buy nothing and add a second thing to keep in step.
  - Entries are frozen dataclasses: immutable and hashable, so one caller cannot corrupt the dataset for another.
  - Published by GitHub Actions through Trusted Publishing (OIDC). Build and publish are separate jobs, so no test or dependency-install step ever runs while a publishable token is in scope.

### Changed

- `npm run verify` now covers all four registries: version parity across npm, NuGet, pub.dev and PyPI, and a staleness diff over the JSON copied into the Python package. Both were verified by forcing a mismatch and watching them fail.

---

## [0.3.3]

### Fixed

- **pub.dev package description** shortened to 170 characters. pub.dev wants 60–180 and search engines truncate beyond that; the previous 212-character version cost 10 pub points and read as a run-on in results.

### Changed

- npm and NuGet catch up to 0.3.3. pub.dev received 0.3.2 first — its initial release has to be published by hand before automation can be configured — so the three registries were briefly out of step. They ship from one tag again from here.

---

## [0.3.2]

### Added

- **Automated publishing to pub.dev** from a tag push, via the Dart team's reusable workflow. pub.dev only accepts automated publishing triggered by a tag, so there is deliberately no `workflow_dispatch` escape hatch — it would fail every time it was used.
- **`menuella_food_safety` on pub.dev** — the same dataset for Dart and Flutter.
  - `getDisclosures(locale)`, `getIcon(name)`, `iconToSvg(name, …)`, plus `locales`, `allergenKeys`, `declarationKeys`, `iconNames`, `codeScheme` and the `isLocale` / `isAllergenKey` / `isDeclarationKey` guards.
  - **No dependencies, and no `dart:io`** — the data is generated Dart source, so it behaves identically on the VM, on Flutter, and on the web. A package that read JSON from disk could not run on Flutter web at all.
  - Its own README written for Dart developers; the root README documents the npm entry points and would send them to the wrong install command.

### Changed

- The root README is a **polyglot front page** rather than a JS API reference: 492 → 209 lines. The long rendering guide moved to [`docs/rendering.md`](docs/rendering.md), the on-disk format to [`docs/data-shapes.md`](docs/data-shapes.md), and the repo workflow into `CONTRIBUTING.md`.
- `npm run verify` now diffs the generated Dart alongside the generated JS, so a forgotten `npm run generate` cannot ship a stale binding.
- The generator formats its own Dart output with an explicit `--language-version`. `dart format` picks its style from the package's language version, and the verifier builds into a temp directory with no `pubspec.yaml` — without the pin, the temp build got the newer "tall" style and every run reported a stale file that was perfectly in sync.

---

## [0.3.1]

### Changed

- NuGet package metadata completed against [NuGet's package authoring guidance](https://learn.microsoft.com/en-us/nuget/create-packages/package-authoring-best-practices): adds `Copyright`, a 128×128 transparent-background `PackageIcon`, and `PackageReleaseNotes` pointing at this changelog.
- The deprecated `IconUrl` / `LicenseUrl` forms are deliberately not used — they resolve at display time, so changing the target would retroactively change what every past version appears to say.

No code or data changed; 0.3.0 and 0.3.1 are the same vocabulary.

---

## [0.3.0]

### Added

- **`Menuella.FoodSafety` on NuGet** — the same dataset for .NET, published by the same tag as the npm release.
  - `Disclosures.Get(locale)`, `AllergenKeys`, `DeclarationKeys`, `Locales`, `CodeScheme`, `IsAllergenKey` / `IsDeclarationKey` / `IsLocale`.
  - `Icons.Get(name)` → `{ ViewBox, Nodes }` for callers that build elements; `Icons.ToSvg(name, size, cssClass, title)` for templates that interpolate markup (Razor, e-mail, PDF).
  - Targets **net10.0**, with **zero PackageReferences** — System.Text.Json is in-box, so "no dependencies" holds on this registry too.
  - Trimmable and AOT-compatible.
  - It **embeds the same JSON** the npm package ships rather than transcribing it into C#. A transcription is a second copy, and a second copy drifts.
  - Published via NuGet Trusted Publishing (OIDC) — no API key exists anywhere.

### Changed

- Repo moves to a polyglot layout: language bindings live under `packages/<lang>/`, with `data/`, `icons/`, `schemas/` and `docs/` staying at the root as the single source. The npm package has **not** moved yet — that changes published file paths and is a separate step.
- `npm run verify` now fails when the npm and NuGet versions disagree. They ship the same data from the same tag, so a drift would mean one version number naming two different vocabularies.

---

## [0.2.1]

### Fixed

- `IconNode` typed `fill`, `fillRule` and `clipRule` as `string`. That compiles inside this package but **not where it matters**: React types `fillRule` as an enum, so a widened `string` is not assignable to `SVGProps<SVGPathElement>` and every React consumer needed a cast to spread the attributes — defeating the entire point of handing out nodes instead of a markup string. Narrowed to the values that actually occur (`"currentColor"`, `"evenodd" | "nonzero"`), so nodes now spread as-is.

Types only; the runtime data is byte-identical to 0.2.0.

---

## [0.2.0]

### Added

- **`@menuella/food-safety/icons`** — the 15 glyphs as a renderable API, not just files on disk.
  - `getIcon(name)` → `{ viewBox, nodes }` for frameworks that build real elements (React, Svelte, Vue). No `innerHTML` on a legal surface.
  - `getIconSvg(name, { size, className, title })` → an `<svg>` string for templates that interpolate markup (Astro `set:html`, e-mail, PDF).
  - Both inline `fill="currentColor"`, so a glyph follows a light/dark theme with no prop and no second asset — which an `<img>` cannot do.
  - Decorative by default (`aria-hidden`, `focusable="false"`); pass `title` for `role="img"` with a `<title>`. The declaration text must always be present regardless: an icon must never be the only thing declaring an allergen.
  - `ICONS_AVAILABLE`, plus `Icon` / `IconNode` / `IconSvgOptions` types.

Deliberately **not** a React component: this package has no framework in its dependency list, and is consumed from both Astro and React inside Menuella alone. A component would pick a winner and add a peer dependency.

Its own entry point, so consumers that only want the vocabulary never download the path data — a guards-only import is still 647 B gzipped, and an icons-only import carries no locale data.

### Changed

- `scripts/generate.mjs` now parses `icons/*.svg` into `data/icons.json` (plus a `.js` twin, like the bundles). The parser **fails the build** on an unsupported attribute or on any shape that is not `fill="currentColor"` — a glyph that cannot follow the theme is a bug, and louder as a build failure than as a mystery in production.


## [0.1.1] – 2026-07-31

### Changed

- `homepage` now points at [menuella.com/food-safety](https://www.menuella.com/food-safety) rather than the repository. The npm sidebar links `repository` separately, so the homepage is free to be documentation.

### Removed

- The explorer moved out of this repository to menuella.com. This package is the dataset; browsing it is the website's job.

---

## [0.1.0] – 2026-07-31

Initial release.

### Contents

- **Allergens** — `data/allergens.json`, 28 keys covering the 14 EU/LMIV groups of Reg. 1169/2011 Annex II. Gluten-containing cereals and tree nuts are expanded into their specific members, because LMIV requires naming the exact cereal or nut; the group survives as `group` plus a localized `declaration` sentence.
- **Menuella Declarations** — `data/declarations.json`, 22 keys: additive declarations plus beverage declarations, mandatory warnings and other product-specific indications, distinguished by `category`. Menuella's standardized menu disclosure vocabulary, designed for portability across regions rather than to mirror any country's official legal terminology. Inspired by common German restaurant menu practice, then generalized — packaging-only entries (protective atmosphere, iodised salt, cocoa fat glaze, taurine, GMO notes, oxygen colour stabilisation, elevated-caffeine package warnings) were excluded as unsuitable for a menu.
- **Translations** — `data/translations/<module>/<lang>.json` in 6 languages (de, en, es, fr, it, tr), as objects keyed by the structural key. Every language is complete.
- **Menuella footnote codes** — `data/codes.json`, the short code printed in a menu legend (`WHEAT` → `A6`, `SWEETENERS` → `12`). One scheme, usable in any region: the letters follow established EU menu practice, the numbers are Menuella's own contiguous 1–22. Separate from the keys by design — a code is a rendering convention, never an identity.
- **Schemas** — one structural and one translation schema per module, with the key vocabularies enumerated so an unknown key fails validation.
- **Icons** — `icons/`, 15 solid 24×24 SVG glyphs using `currentColor` and no stroke, one per allergen group plus one for declarations. Named after the group, not after what they depict, so a redraw never changes the contract.
- **Bundles** — `bundles/<locale>.json`, structure + labels + icon pre-joined so a client renders with no lookup of its own. Each carries a `fallbacks` array so any field served from `en` is inspectable rather than silent.
- **Typed entry point** — `index.js` / `index.d.ts`: key constants, type guards and every type, all generated from the data so they cannot drift. Zero dependencies, nothing to compile.

### Design decisions

- **Keys, not codes — but codes are shipped.** Entries are identified by stable semantic keys (`WHEAT`, `NITRITE_CURING_SALT`). The printed codes (`A6`, `11`) live in `data/codes.json`, so a menu can be rendered with numbers without the numbers ever becoming the identity. National legends are not standardized between print shops or states — the same number means different things on two menus — which is why Menuella defines one scheme rather than mirroring any of them. Store keys, render codes, never the reverse. See [`regions.md`](docs/regions.md).
- **Structure and language never mix.** Structural files carry no language; translation files carry no structure. Adding a language adds one file per module and cannot clobber another translation.
- **Translations are keyed objects, not arrays.** A lookup is `labels[key]` — no join step, no scanning.
- **One standard, not ten legal references.** Menuella Declarations are a single portable vocabulary used in every supported region, not a per-country legal mapping. That keeps the API stable, keeps the docs from exploding country by country, and leaves room to add internal legal mappings later without changing the public keys.
- **Safety only.** Preference, lifestyle and taste vocabularies (vegan, halal, spiciness) are deliberately out of scope. They are real menu attributes, but they are not safety disclosures.
- **Menu scope only.** No packaged-retail or manufacturer-specific labelling rules.
