#!/usr/bin/env node
// What each entry point costs a consumer's bundle, and which locale data it
// pulls in. Bundles a tiny consumer for each entry point with esbuild — through
// a real node_modules link, so the package's `exports` map is what resolves
// the imports — then checks two things:
//
//   size      gzip bytes against a budget
//   content   which locales' labels are in the output
//
// Content is the stronger check. A budget only says "small enough"; a label
// from the wrong locale in the output says exactly what leaked.
//
//   npm run size
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { gzipSync } from "node:zlib"
import { build } from "esbuild"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const NAME = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).name

const locales = readdirSync(join(ROOT, "data/translations/allergens"))
  .filter((f) => f.endsWith(".json"))
  .map((f) => f.replace(/\.json$/, ""))
  .sort()

// One label per locale that appears in no other locale — not even inside a
// longer label, since the search below is a substring search — as its
// fingerprint in a bundle. Variants of one language share most labels, so
// this searches every field rather than assuming any particular one differs.
const labelsOf = (l) => {
  const b = JSON.parse(readFileSync(join(ROOT, "data/bundles", `${l}.json`), "utf8"))
  return new Set([...b.allergens, ...b.declarations].flatMap((e) =>
    [e.name, e.declaration, e.description].filter(Boolean)))
}
const labels = Object.fromEntries(locales.map((l) => [l, labelsOf(l)]))
const marker = {}
for (const l of locales) {
  const others = locales.filter((o) => o !== l)
  marker[l] = [...labels[l]]
    .sort((a, b) => b.length - a.length)
    .find((s) => others.every((o) => ![...labels[o]].some((t) => t.includes(s))))
  if (!marker[l]) throw new Error(`${l} has no label of its own — two locales are identical`)
}
const localesIn = (code) => locales.filter((l) => code.includes(marker[l]))

let failed = 0
const check = (label, ok, detail = "") => {
  if (!ok) failed++
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${label}${detail ? `  ${detail}` : ""}`)
}
const kb = (n) => `${(n / 1024).toFixed(2)} kB`
const gz = (code) => gzipSync(code, { level: 9 }).length

// A consumer project whose node_modules points at this checkout.
const work = mkdtempSync(join(tmpdir(), "food-safety-size-"))
mkdirSync(join(work, "node_modules", dirname(NAME)), { recursive: true })
symlinkSync(ROOT, join(work, "node_modules", NAME), "dir")

const bundle = async (source, { splitting = false } = {}) => {
  const entry = join(work, `entry-${Math.random().toString(36).slice(2)}.js`)
  writeFileSync(entry, source)
  const out = join(work, "out", `${Math.random().toString(36).slice(2)}`)
  const result = await build({
    entryPoints: [entry],
    absWorkingDir: work,
    bundle: true,
    minify: true,
    format: "esm",
    platform: "browser",
    // Labels stay readable in the output, so the markers can be found.
    charset: "utf8",
    splitting,
    outdir: out,
    write: false,
    logLevel: "silent",
  })
  const files = result.outputFiles.map((f) => ({ path: f.path, code: f.text }))
  return { entry: files.find((f) => f.path.endsWith(".js") && f.path.includes("entry-")), files }
}

try {
  console.log("\nroot — the contract")
  {
    const { entry } = await bundle(`import * as fs from "${NAME}"; globalThis.fs = fs`)
    const size = gz(entry.code)
    check("no locale data", localesIn(entry.code).length === 0, localesIn(entry.code).join(", "))
    check(`≤ 1.5 kB gzip`, size <= 1536, kb(size))
  }

  console.log("\nlocales/<tag> — one locale, static")
  {
    let largest = 0
    for (const l of locales) {
      const { entry } = await bundle(`import d from "${NAME}/locales/${l}"; globalThis.d = d`)
      const found = localesIn(entry.code)
      largest = Math.max(largest, gz(entry.code))
      check(`${l} carries only ${l}`, found.length === 1 && found[0] === l, found.join(", "))
    }
    check(`largest locale ≤ 4 kB gzip`, largest <= 4096, kb(largest))
  }

  console.log("\nload — one chunk per locale, fetched on demand")
  {
    const { entry, files } = await bundle(
      `import { loadDisclosures } from "${NAME}/load"; globalThis.load = loadDisclosures`,
      { splitting: true },
    )
    const size = gz(entry.code)
    check("entry chunk has no locale data", localesIn(entry.code).length === 0,
      localesIn(entry.code).join(", "))
    check(`entry chunk ≤ 1.5 kB gzip`, size <= 1536, kb(size))
    const chunks = files.filter((f) => f !== entry && f.path.endsWith(".js"))
    const perChunk = chunks.map((f) => localesIn(f.code)).filter((found) => found.length > 0)
    check("every locale in a chunk of its own",
      perChunk.length === locales.length && perChunk.every((found) => found.length === 1) &&
        new Set(perChunk.flat()).size === locales.length,
      `${perChunk.length} locale chunks for ${locales.length} locales`)
  }

  console.log("\nall — every locale, synchronous")
  {
    const { entry } = await bundle(`import { getDisclosures } from "${NAME}/all"; globalThis.g = getDisclosures`)
    check("carries every locale", localesIn(entry.code).length === locales.length,
      `${localesIn(entry.code).length}/${locales.length} · ${kb(gz(entry.code))} gzip`)
  }
} finally {
  rmSync(work, { recursive: true, force: true })
}

console.log(failed ? `\n${failed} CHECK(S) FAILED` : "\nALL CHECKS PASSED")
process.exit(failed ? 1 : 0)
