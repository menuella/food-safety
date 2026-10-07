// Runtime behaviour of the published entry points.
//
// `npm run verify` checks the DATA is correct; this checks the CODE that hands
// it out — immutability, guards, error contracts, and which entry point
// carries what. Uses node:test, so there is no test dependency.
//
// Locale modules are imported by the PACKAGE name, not by relative path, so the
// `exports` map is exercised exactly as a consumer would hit it.
import { test } from "node:test"
import assert from "node:assert/strict"

import * as root from "../index.js"
import {
  ALLERGEN_GROUPS,
  ALLERGEN_KEYS,
  CODE_SCHEME,
  DECLARATION_CATEGORIES,
  DECLARATION_KEYS,
  FALLBACK_LOCALE,
  ICON_NAMES,
  LOCALES,
  isAllergenKey,
  isDeclarationKey,
  isLocale,
  resolveDisclosures,
} from "../index.js"
import { getDisclosures } from "../all.js"
import { loadDisclosures } from "../load.js"
import { ICONS_AVAILABLE, getIcon, getIconSvg } from "../icons.js"

const importLocale = async (tag) =>
  (await import(`@menuella/food-safety/locales/${tag}`)).default

// ------------------------------------------------------------ entry points ---

test("the root entry point carries the contract and no locale data", () => {
  // An exact list, so a re-added data export (or a new one) is a decision
  // someone has to make here rather than an accident.
  assert.deepEqual(Object.keys(root).sort(), [
    "ALLERGEN_GROUPS", "ALLERGEN_KEYS", "CODE_SCHEME", "DECLARATION_CATEGORIES",
    "DECLARATION_KEYS", "FALLBACK_LOCALE", "ICON_NAMES", "LOCALES",
    "isAllergenKey", "isDeclarationKey", "isLocale", "resolveDisclosures",
  ])
})

test("every locale is reachable three ways, and all three are the same object", async () => {
  for (const locale of LOCALES) {
    const imported = await importLocale(locale)
    assert.equal(imported.locale, locale)
    assert.equal(await loadDisclosures(locale), imported, `${locale}: load`)
    assert.equal(getDisclosures(locale), imported, `${locale}: all`)
  }
})

test("every locale resolves to a complete bundle of its own", () => {
  for (const locale of LOCALES) {
    const d = getDisclosures(locale)
    assert.equal(d.locale, locale, `${locale} bundle reports the wrong locale`)
    assert.equal(d.allergens.length, ALLERGEN_KEYS.length)
    assert.equal(d.declarations.length, DECLARATION_KEYS.length)
    assert.equal(d.fallbackLocale, FALLBACK_LOCALE)
    assert.ok(Array.isArray(d.fallbacks))
  }
})

test("locales actually differ from each other", () => {
  // Guards against two bundles being generated from the same file. Fingerprint
  // each locale by every label it carries rather than one entry: two locales
  // can share an incidental word (Danish and Norwegian both call RYE "Rug"),
  // and two variants of one language share many — but never all of them.
  const fingerprints = LOCALES.map((l) => {
    const { allergens, declarations } = getDisclosures(l)
    return JSON.stringify([allergens, declarations])
  })
  assert.equal(new Set(fingerprints).size, fingerprints.length,
    "at least two locales carry identical labels")
})

test("locale tags are BCP 47, and a language with variants has no bare tag", () => {
  for (const tag of LOCALES) {
    assert.match(tag, /^[a-z]{2}(-[A-Z]{2}|-[A-Z][a-z]{3})?$/, tag)
  }
  // Shipping "pt" beside "pt-BR" would make "pt" mean one of them silently.
  // A caller holding a bare language must choose the variant themselves.
  for (const tag of LOCALES) {
    const base = tag.split("-")[0]
    if (base !== tag) assert.ok(!LOCALES.includes(base), `${base} ships beside ${tag}`)
  }
})

// Pick a two-letter code this package does not ship. Sweeps every "aa"…"zz" and
// returns the first that isn't in LOCALES, so this test does not need editing
// when a new locale is added — it will only stop working once we somehow ship
// all 676 two-letter codes, at which point a hard-coded fallback would be worse.
const pickNegativeLocale = () => {
  const shipped = new Set(LOCALES)
  for (let i = 0; i < 26; i++) {
    for (let j = 0; j < 26; j++) {
      const c = String.fromCharCode(97 + i) + String.fromCharCode(97 + j)
      if (!shipped.has(c)) return c
    }
  }
  throw new Error("every two-letter code is a shipped locale")
}

test("an unsupported locale throws, and says what exists", () => {
  const sample = pickNegativeLocale()
  let err
  try {
    getDisclosures(sample)
  } catch (caught) {
    err = caught
  }
  assert.ok(err, `expected getDisclosures(${JSON.stringify(sample)}) to throw`)
  assert.match(err.message, new RegExp(`No disclosures for locale "${sample}"`))
  assert.equal(err.code, "ERR_UNSUPPORTED_LOCALE")
  // The message must name every locale that does work, or it is not actionable.
  for (const locale of LOCALES) assert.ok(err.message.includes(locale), locale)
})

test("loadDisclosures rejects an unsupported locale the same way", async () => {
  await assert.rejects(loadDisclosures(pickNegativeLocale()), { code: "ERR_UNSUPPORTED_LOCALE" })
  await assert.rejects(loadDisclosures(undefined), { code: "ERR_UNSUPPORTED_LOCALE" })
})

test("non-locale inputs throw rather than returning something", async () => {
  // `__proto__` and `constructor` would resolve on a plain object lookup. A
  // variant tag is matched exactly: no case folding, no prefix match.
  for (const input of ["__proto__", "constructor", "toString", "", "DE", " de ",
                       "pt", "zh", "pt-br", "PT-BR", "zh-hant", "zh_Hant",
                       null, undefined, 0, {}]) {
    assert.throws(() => getDisclosures(input), { code: "ERR_UNSUPPORTED_LOCALE" },
      `expected ${JSON.stringify(input)} to be rejected`)
    await assert.rejects(loadDisclosures(input), { code: "ERR_UNSUPPORTED_LOCALE" },
      `expected ${JSON.stringify(input)} to be rejected by load`)
    assert.equal(isLocale(input), false)
  }
})

test("a bundle cannot be mutated by one consumer and poison another", () => {
  const first = getDisclosures("de")
  assert.throws(() => first.allergens.push({}), TypeError)
  assert.throws(() => { first.allergens[0].name = "tampered" }, TypeError)
  assert.throws(() => { first.locale = "xx" }, TypeError)

  const second = getDisclosures("de")
  assert.equal(second.allergens.length, ALLERGEN_KEYS.length)
  assert.equal(second.allergens[0].name, "Roggen")
})

test("a locale module is frozen all the way down on import", async () => {
  // Imported directly, with nothing else having touched it first.
  const d = await importLocale("en")
  assert.ok(Object.isFrozen(d))
  assert.ok(Object.isFrozen(d.allergens))
  assert.ok(Object.isFrozen(d.allergens[0]))
  assert.ok(Object.isFrozen(d.declarations[0]))
  assert.ok(Object.isFrozen(d.fallbacks))
})

// -------------------------------------------------------------- vocabulary ---

test("key guards accept current keys and reject retired codes", () => {
  for (const key of ALLERGEN_KEYS) assert.ok(isAllergenKey(key), key)
  for (const key of DECLARATION_KEYS) assert.ok(isDeclarationKey(key), key)

  // The retired German codes are the whole reason these guards exist.
  for (const code of ["A6", "G", "A", "H", "11", "4", "23"]) {
    assert.equal(isAllergenKey(code), false, code)
    assert.equal(isDeclarationKey(code), false, code)
  }
})

test("key guards reject non-strings and near-misses without throwing", () => {
  for (const value of [null, undefined, 0, 1, {}, [], true, Symbol("WHEAT"), () => {}]) {
    assert.equal(isAllergenKey(value), false)
    assert.equal(isDeclarationKey(value), false)
    assert.equal(isLocale(value), false)
  }
  // Case and whitespace are not normalized — callers must pass canonical keys.
  for (const value of ["wheat", "Wheat", " WHEAT", "WHEAT "]) {
    assert.equal(isAllergenKey(value), false, value)
  }
  assert.equal(isAllergenKey("toString"), false)
  assert.equal(isLocale("toString"), false)
})

test("locale guard matches the shipped bundles exactly", () => {
  for (const locale of LOCALES) assert.ok(isLocale(locale))
  assert.equal(isLocale(pickNegativeLocale()), false)
})

test("every entry references a real icon, group and category", () => {
  for (const locale of LOCALES) {
    const { allergens, declarations } = getDisclosures(locale)
    for (const a of allergens) {
      assert.ok(ICON_NAMES.includes(a.icon), `${a.key} icon ${a.icon}`)
      assert.ok(ALLERGEN_GROUPS.includes(a.group), `${a.key} group ${a.group}`)
      assert.equal(typeof a.declaration, "string")
      assert.ok(a.declaration.length > 0)
    }
    for (const d of declarations) {
      assert.ok(ICON_NAMES.includes(d.icon), `${d.key} icon ${d.icon}`)
      assert.ok(DECLARATION_CATEGORIES.includes(d.category), `${d.key} category ${d.category}`)
    }
  }
})

test("members of a group share one declaration sentence, in every locale", () => {
  // The rendering rule resolveDisclosures relies on: one declaration per
  // group, members beneath it. A locale that gave two members of one group
  // different sentences would make "the group's declaration" ambiguous.
  for (const locale of LOCALES) {
    const byGroup = new Map()
    for (const a of getDisclosures(locale).allergens) {
      byGroup.set(a.group, [...(byGroup.get(a.group) ?? []), a])
    }
    for (const [group, members] of byGroup) {
      const sentences = new Set(members.map((m) => m.declaration))
      assert.equal(sentences.size, 1, `${locale}/${group} has ${sentences.size} different declarations`)
    }
  }
})

test("exported vocabularies are immutable", () => {
  for (const frozen of [LOCALES, ALLERGEN_KEYS, DECLARATION_KEYS, ALLERGEN_GROUPS,
                        DECLARATION_CATEGORIES, ICON_NAMES]) {
    assert.ok(Object.isFrozen(frozen))
  }
  assert.equal(CODE_SCHEME, "MENUELLA")
})

// ------------------------------------------------------ resolveDisclosures ---

test("resolveDisclosures states each group once, with its members beneath", () => {
  const en = getDisclosures("en")
  const r = resolveDisclosures(en, ["BARLEY", "WHEAT", "MILK"])

  assert.deepEqual(r.allergens.map((g) => g.group), ["CEREALS", "MILK"])
  const cereals = r.allergens[0]
  assert.equal(cereals.declaration, en.allergens.find((a) => a.key === "WHEAT").declaration)
  assert.equal(cereals.icon, "cereals")
  // Dataset order, not input order: barley was asked for first.
  assert.deepEqual(cereals.members.map((m) => m.key),
    en.allergens.filter((a) => a.key === "WHEAT" || a.key === "BARLEY").map((a) => a.key))
  // A single-member group has nothing to list beneath its declaration.
  assert.deepEqual(r.allergens[1].members, [])
  assert.deepEqual(r.declarations, [])
  assert.deepEqual(r.unknown, [])
})

test("resolveDisclosures keeps unknown keys instead of dropping them", () => {
  const r = resolveDisclosures(getDisclosures("de"), ["A6", "WHEAT", "SWEETENERS", "A6", "NEW_KEY"])
  assert.deepEqual(r.unknown, ["A6", "NEW_KEY"])
  assert.deepEqual(r.allergens.map((g) => g.group), ["CEREALS"])
  assert.deepEqual(r.declarations.map((d) => d.key), ["SWEETENERS"])
})

test("resolveDisclosures orders groups and declarations by the dataset", () => {
  const de = getDisclosures("de")
  const everything = [...ALLERGEN_KEYS, ...DECLARATION_KEYS].reverse()
  const r = resolveDisclosures(de, everything)
  assert.deepEqual(r.allergens.map((g) => g.group),
    [...new Set(de.allergens.map((a) => a.group))])
  assert.deepEqual(r.declarations, de.declarations)
  assert.equal(r.allergens.reduce((n, g) => n + Math.max(g.members.length, 1), 0),
    ALLERGEN_KEYS.length)
})

test("resolveDisclosures refuses a single string instead of spelling it out", () => {
  assert.throws(() => resolveDisclosures(getDisclosures("en"), "WHEAT"), TypeError)
  // A Set is a list of keys too.
  const r = resolveDisclosures(getDisclosures("en"), new Set(["WHEAT"]))
  assert.deepEqual(r.allergens.map((g) => g.group), ["CEREALS"])
})

test("resolveDisclosures with no keys resolves to nothing", () => {
  const r = resolveDisclosures(getDisclosures("en"), [])
  assert.deepEqual(r, { allergens: [], declarations: [], unknown: [] })
})

// ------------------------------------------------------------------ icons ---

test("every icon the data references has a glyph", () => {
  for (const name of ICON_NAMES) {
    const icon = getIcon(name)
    assert.equal(icon.viewBox, "0 0 24 24")
    assert.ok(icon.nodes.length > 0, `${name} has no shapes`)
  }
  // The reverse direction too: a glyph nothing references is dead weight in
  // the tarball, and usually means a rename landed on one side only.
  assert.deepEqual([...ICONS_AVAILABLE].sort(), [...ICON_NAMES].sort())
})

test("every shape paints with currentColor, or theming silently breaks", () => {
  for (const name of ICONS_AVAILABLE) {
    for (const [tag, attrs] of getIcon(name).nodes) {
      assert.equal(attrs.fill, "currentColor", `${name}: <${tag}> is not currentColor`)
    }
  }
})

test("icons are deeply frozen, so one consumer cannot corrupt another", () => {
  const icon = getIcon("sesame")
  assert.ok(Object.isFrozen(icon))
  assert.ok(Object.isFrozen(icon.nodes))
  assert.ok(Object.isFrozen(icon.nodes[0][1]))
})

test("an unknown icon throws with a code, it does not return undefined", () => {
  let error
  try {
    getIcon("wine")
  } catch (thrown) {
    error = thrown
  }
  assert.ok(error, "expected a throw")
  assert.equal(error.code, "ERR_UNKNOWN_ICON")
  assert.match(error.message, /Available:/)
})

test("getIconSvg is decorative by default — the text carries the meaning", () => {
  const svg = getIconSvg("milk")
  assert.match(svg, /aria-hidden="true"/)
  assert.match(svg, /focusable="false"/)
  assert.doesNotMatch(svg, /role="img"/)
  assert.doesNotMatch(svg, /<title>/)
})

test("a title turns the glyph into its own accessible element", () => {
  const svg = getIconSvg("milk", { title: "Milk" })
  assert.match(svg, /role="img"/)
  assert.match(svg, /<title>Milk<\/title>/)
  assert.doesNotMatch(svg, /aria-hidden/)
})

test("a caller-supplied title cannot inject markup", () => {
  const svg = getIconSvg("milk", { title: "</title><script>alert(1)</script>" })

  // Asserted as a string, not as a /<script>/ regex. A tag-shaped regex only
  // ever proves the one spelling it happens to spell: `<SCRIPT>`, `<script >`
  // and `</script foo="bar">` are all accepted by browsers and would walk
  // straight past it. The whole hostile title has to survive as ONE text node
  // with every bracket escaped, and that is an exact string.
  assert.ok(
    svg.includes(
      "<title>&lt;/title&gt;&lt;script&gt;alert(1)&lt;/script&gt;</title>",
    ),
    svg,
  )

  // The stronger statement the escaping makes: none of the caller's four angle
  // brackets opened a tag, so the markup has exactly as many `<` as the same
  // glyph rendered with a harmless title. Counting brackets needs no notion of
  // what a tag looks like, so nothing here can be spelled around.
  const benign = getIconSvg("milk", { title: "Milk" })
  assert.equal(svg.split("<").length, benign.split("<").length)
})

test("getIconSvg emits hyphenated SVG attribute names, not the React spelling", () => {
  // fillRule/clipRule are how the DATA carries them; markup needs fill-rule.
  const withRule = ICONS_AVAILABLE.map((n) => getIconSvg(n)).join("")
  assert.doesNotMatch(withRule, /fillRule|clipRule/)
})

test("fillRule/clipRule only ever carry values React's SVG types accept", () => {
  // icons.d.ts narrows these to an enum so the attributes spread straight into
  // React without a cast. A new glyph drawn with a different value would make
  // that type a lie, and this is where it surfaces.
  const allowed = new Set(["evenodd", "nonzero"])
  for (const name of ICONS_AVAILABLE) {
    for (const [tag, attrs] of getIcon(name).nodes) {
      for (const key of ["fillRule", "clipRule"]) {
        if (attrs[key] !== undefined) {
          assert.ok(allowed.has(attrs[key]), `${name}: <${tag}> ${key}="${attrs[key]}"`)
        }
      }
    }
  }
})

test("size and className reach the root element", () => {
  const svg = getIconSvg("eggs", { size: 16, className: "h-4 w-4" })
  assert.match(svg, /width="16" height="16"/)
  assert.match(svg, /class="h-4 w-4"/)
})
