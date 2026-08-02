#!/usr/bin/env node
// Validates the dataset: JSON Schema, cross-file key integrity, icon coverage,
// footnote codes, and that every generated file still matches its sources.
//
//   npm run verify
import { readFileSync, readdirSync, existsSync, mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { execFileSync } from "node:child_process"
import Ajv from "ajv"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const read = (p) => JSON.parse(readFileSync(join(ROOT, p), "utf8"))
const ajv = new Ajv({ allErrors: true, strict: false })

let failed = 0
const check = (label, ok, detail = "") => {
  if (!ok) failed++
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${label}${detail ? `  ${detail}` : ""}`)
}
const section = (name) => console.log(`\n${name}`)

const locales = readdirSync(join(ROOT, "data/translations/allergens"))
  .filter((f) => f.endsWith(".json"))
  .map((f) => f.replace(/\.json$/, ""))
  .sort()

// ------------------------------------------------------------------ schema ---
section("schema validation")
const pairs = [
  ["data/allergens.json", "schemas/allergen.schema.json"],
  ["data/declarations.json", "schemas/declaration.schema.json"],
  ["data/codes.json", "schemas/code.schema.json"],
]
for (const module of ["allergens", "declarations"]) {
  for (const locale of locales) {
    pairs.push([
      `data/translations/${module}/${locale}.json`,
      `schemas/${module.slice(0, -1)}-translation.schema.json`,
    ])
  }
}
// One compiled validator per schema — ajv rejects registering the same $id
// twice, and the translation schemas are reused across every locale.
const validators = new Map()
const validatorFor = (schema) => {
  if (!validators.has(schema)) validators.set(schema, ajv.compile(read(schema)))
  return validators.get(schema)
}
for (const [data, schema] of pairs) {
  const validate = validatorFor(schema)
  const ok = validate(read(data))
  check(data, ok, ok ? "" : ajv.errorsText(validate.errors).slice(0, 90))
}

// ------------------------------------------------------------- integrity ----
section("cross-file key integrity")
const allergens = read("data/allergens.json")
const declarations = read("data/declarations.json")
const aKeys = allergens.map((a) => a.key)
const dKeys = declarations.map((a) => a.key)
check("allergen keys unique", new Set(aKeys).size === aKeys.length)
check("declaration keys unique", new Set(dKeys).size === dKeys.length)

for (const [module, keys] of [["allergens", aKeys], ["declarations", dKeys]]) {
  for (const locale of locales) {
    const rows = read(`data/translations/${module}/${locale}.json`)
    const orphans = Object.keys(rows).filter((k) => !keys.includes(k))
    const missing = keys.filter((k) => !(k in rows))
    check(
      `${module}/${locale}`,
      orphans.length === 0 && missing.length === 0,
      orphans.length || missing.length
        ? `orphans=${orphans} missing=${missing}`
        : `${Object.keys(rows).length}/${keys.length}`,
    )
  }
}

// ---------------------------------------------------------------- icons -----
section("icons")
const iconFiles = new Set(
  readdirSync(join(ROOT, "icons"))
    .filter((f) => f.endsWith(".svg"))
    .map((f) => f.replace(/\.svg$/, "")),
)
const referenced = new Set([...allergens, ...declarations].map((a) => a.icon))
check("every referenced icon exists", [...referenced].every((i) => iconFiles.has(i)),
  `${referenced.size} referenced`)
check("no unused icon files", [...iconFiles].every((i) => referenced.has(i)),
  `${iconFiles.size} files`)
check(
  "group icons are kebab(group)",
  allergens.every((a) => a.icon === a.group.toLowerCase().replace(/_/g, "-")),
)

// The drawing may change freely — the NAME is the contract, not the art. What
// may not change is the style contract every consumer relies on: a 24x24 box,
// colour taken from `currentColor`, and no stroke. A redraw that hardcodes a
// colour would silently break theming everywhere it is used.
const iconProblems = []
for (const name of [...iconFiles].sort()) {
  const svg = readFileSync(join(ROOT, "icons", `${name}.svg`), "utf8")
  const fail = (why) => iconProblems.push(`${name}.svg: ${why}`)

  if (!/viewBox="0 0 24 24"/.test(svg)) fail("viewBox is not 0 0 24 24")
  if (!/<svg[^>]*\sfill="none"/.test(svg)) fail('root <svg> missing fill="none"')
  if (/<svg[^>]*\s(width|height)=/.test(svg)) fail("root has fixed width/height — must scale")

  // Every paint must be currentColor or none; anything else defeats theming.
  for (const [, value] of svg.matchAll(/\bfill="([^"]+)"/g)) {
    if (value !== "currentColor" && value !== "none") fail(`hardcoded fill "${value}"`)
  }
  if (/\bstroke="(?!none)/.test(svg)) fail("has a stroke — the set is solid")
  if (/<(style|image|script)\b/.test(svg)) fail("contains <style>, <image> or <script>")
  // xmlns="http://www.w3.org/2000/svg" is a namespace declaration, not a fetch —
  // only href/xlink:href/url() actually pull something in.
  if (/(?:\bhref|xlink:href)="[^"]*https?:\/\//.test(svg) || /url\(\s*['"]?https?:/.test(svg)) {
    fail("references an external URL")
  }
}
check("icons meet the style contract", iconProblems.length === 0,
  iconProblems.length ? iconProblems.slice(0, 3).join("; ") : `${iconFiles.size} checked`)

// ---------------------------------------------------------------- codes -----
section("Menuella footnote codes")
const codes = read("data/codes.json")
check("scheme is MENUELLA", codes.scheme === "MENUELLA")
for (const [module, keys] of [["allergens", aKeys], ["declarations", dKeys]]) {
  const values = Object.values(codes[module])
  const missing = keys.filter((k) => !(k in codes[module]))
  check(`codes/${module}: every key has a code`, missing.length === 0,
    missing.length ? `missing=${missing}` : "")
  check(`codes/${module}: codes unique`, new Set(values).size === values.length)
}

// ------------------------------------------------------- generated in sync --
section("generated files in sync with sources")
// Build into a throwaway directory and diff. A verifier must never rewrite the
// files it is checking — otherwise a bad source silently corrupts the tree.
let hasDart = true
try { execFileSync("dart", ["--version"], { stdio: "pipe" }) } catch { hasDart = false }
const tmp = mkdtempSync(join(tmpdir(), "food-safety-verify-"))
execFileSync(process.execPath, [join(ROOT, "scripts/generate.mjs"), "--out", tmp], { stdio: "pipe" })
// Every artifact the generator writes. A binding missing from this list ships
// stale data the day someone edits a source file and forgets to regenerate —
// and nothing else would catch it, because the binding's own tests pass
// happily against whatever it was last built from.
const generated = ["index.js", "index.d.ts", "data/icons.json", "data/icons.js",
  // Only when the Dart SDK is present: generate.mjs formats its Dart output,
  // so without dart the temp build is unformatted and would diff against a
  // committed file that is perfectly in sync.
  // The copies pub.dev requires at the package root. Not code, but generated
  // all the same — and a stale CHANGELOG here fails `dart pub publish`, which
  // is a bad place to discover it.
  "packages/dart/CHANGELOG.md", "packages/dart/LICENSE",
  "packages/python/CHANGELOG.md", "packages/python/LICENSE",
  "packages/java/CHANGELOG.md", "packages/java/LICENSE",
  "packages/swift/Sources/MenuellaFoodSafety/Resources/allergens.json",
  "packages/swift/Sources/MenuellaFoodSafety/Resources/declarations.json",
  "packages/swift/Sources/MenuellaFoodSafety/Resources/codes.json",
  "packages/swift/Sources/MenuellaFoodSafety/Resources/icons.json",
  ...locales.map((l) => `packages/swift/Sources/MenuellaFoodSafety/Resources/bundles/${l}.json`),
  "packages/php/data/allergens.json", "packages/php/data/declarations.json",
  "packages/php/data/codes.json", "packages/php/data/icons.json",
  ...locales.map((l) => `packages/php/data/bundles/${l}.json`),
  "packages/java/src/main/kotlin/com/menuella/foodsafety/GeneratedData.kt",
  "packages/java/src/main/kotlin/com/menuella/foodsafety/GeneratedIcons.kt",
  ...locales.map((l) => `packages/java/src/main/kotlin/com/menuella/foodsafety/Bundle${l.toUpperCase()}.kt`),
  "packages/python/src/menuella_food_safety/data/allergens.json",
  "packages/python/src/menuella_food_safety/data/declarations.json",
  "packages/python/src/menuella_food_safety/data/codes.json",
  "packages/python/src/menuella_food_safety/data/icons.json",
  ...locales.map((l) => `packages/python/src/menuella_food_safety/data/bundles/${l}.json`),
  ...(hasDart ? ["packages/dart/lib/src/data.g.dart", "packages/dart/lib/src/icons.g.dart"] : []),
  ...locales.flatMap((l) => [`data/bundles/${l}.json`, `data/bundles/${l}.js`])]
const stale = generated.filter(
  (f) => readFileSync(join(ROOT, f), "utf8") !== readFileSync(join(tmp, f), "utf8"),
)
rmSync(tmp, { recursive: true, force: true })
check("generated files match their sources", stale.length === 0,
  stale.length ? `stale: ${stale.join(", ")} — run \`npm run generate\`` : "")

// ----------------------------------------------------- language bindings ----
section("language bindings")
// npm and NuGet ship the SAME data from the SAME tag, so their versions must
// agree. If they drift, "0.3.0" names two different vocabularies depending on
// which registry you got it from — and nothing else would ever catch that.
const props = join(ROOT, "packages/dotnet/Directory.Build.props")
if (existsSync(props)) {
  const dotnetVersion = /<Version>([^<]+)<\/Version>/.exec(readFileSync(props, "utf8"))?.[1]
  const npmVersion = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version
  check(
    `npm and NuGet versions agree (${npmVersion})`,
    dotnetVersion === npmVersion,
    dotnetVersion === npmVersion ? "" : `Directory.Build.props says ${dotnetVersion}`,
  )
} else {
  console.log("  SKIP  no .NET binding in this checkout")
}

const pubspec = join(ROOT, "packages/dart/pubspec.yaml")
if (existsSync(pubspec)) {
  const dartVersion = /^version:\s*(\S+)/m.exec(readFileSync(pubspec, "utf8"))?.[1]
  const npmVersion = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version
  check(
    `npm and pub.dev versions agree (${npmVersion})`,
    dartVersion === npmVersion,
    dartVersion === npmVersion ? "" : `pubspec.yaml says ${dartVersion}`,
  )
} else {
  console.log("  SKIP  no Dart binding in this checkout")
}

const pyproject = join(ROOT, "packages/python/pyproject.toml")
if (existsSync(pyproject)) {
  const pyVersion = /^version = "([^"]+)"/m.exec(readFileSync(pyproject, "utf8"))?.[1]
  const npmVersion = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version
  check(
    `npm and PyPI versions agree (${npmVersion})`,
    pyVersion === npmVersion,
    pyVersion === npmVersion ? "" : `pyproject.toml says ${pyVersion}`,
  )
} else {
  console.log("  SKIP  no Python binding in this checkout")
}

const gradleProps = join(ROOT, "packages/java/gradle.properties")
if (existsSync(gradleProps)) {
  const jvmVersion = /^version=(.+)$/m.exec(readFileSync(gradleProps, "utf8"))?.[1]?.trim()
  const npmVersion = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version
  check(
    `npm and Maven Central versions agree (${npmVersion})`,
    jvmVersion === npmVersion,
    jvmVersion === npmVersion ? "" : `gradle.properties says ${jvmVersion}`,
  )
} else {
  console.log("  SKIP  no JVM binding in this checkout")
}

// The JVM README is the only one carrying a literal version — Gradle and Maven
// coordinates include it, where `npm i` and `pip install` do not. A stale one
// tells readers to install a version that is not current.
const jvmReadme = join(ROOT, "packages/java/README.md")
if (existsSync(jvmReadme)) {
  const npmVersion = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version
  const stale = [...readFileSync(jvmReadme, "utf8").matchAll(/com\.menuella:food-safety:([\d.]+)|<version>([\d.]+)<\/version>/g)]
    .map((m) => m[1] ?? m[2])
    .filter((v) => v !== npmVersion)
  check(
    `JVM README install snippets say ${npmVersion}`,
    stale.length === 0,
    stale.length ? `found ${[...new Set(stale)].join(", ")}` : "",
  )
}

console.log(failed ? `\n${failed} CHECK(S) FAILED` : "\nALL CHECKS PASSED")
process.exit(failed ? 1 : 0)
