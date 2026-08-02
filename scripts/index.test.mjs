// Runtime behaviour of the published entry point.
//
// `npm run verify` checks the DATA is correct; this checks the CODE that hands
// it out — immutability, guards, error contracts. Uses node:test, so there is
// no test dependency.
import { test } from "node:test"
import assert from "node:assert/strict"

import {
  ALLERGEN_GROUPS,
  ALLERGEN_KEYS,
  CODE_SCHEME,
  DECLARATION_CATEGORIES,
  DECLARATION_KEYS,
  FALLBACK_LOCALE,
  ICON_NAMES,
  LOCALES,
  getDisclosures,
  isAllergenKey,
  isDeclarationKey,
  isLocale,
} from "../index.js"
import { ICONS_AVAILABLE, getIcon, getIconSvg } from "../icons.js"

test("every locale resolves to its own bundle", () => {
  for (const locale of LOCALES) {
    const d = getDisclosures(locale)
    assert.equal(d.locale, locale, `${locale} bundle reports the wrong locale`)
    assert.equal(d.allergens.length, ALLERGEN_KEYS.length)
    assert.equal(d.declarations.length, DECLARATION_KEYS.length)
    assert.equal(d.fallbackLocale, FALLBACK_LOCALE)
    assert.ok(Array.isArray(d.fallbacks))
  }
})

test("labels actually differ between locales", () => {
  // Guards against every bundle being generated from the same language.
  const names = LOCALES.map((l) => getDisclosures(l).allergens[0].name)
  assert.equal(new Set(names).size, names.length, `duplicate labels: ${names}`)
})

test("an unsupported locale throws, and says what exists", () => {
  let err
  try {
    getDisclosures("pt")
  } catch (caught) {
    err = caught
  }
  assert.ok(err, "expected getDisclosures('pt') to throw")
  assert.match(err.message, /No disclosures for locale "pt"/)
  assert.equal(err.code, "ERR_UNSUPPORTED_LOCALE")
  // The message must name every locale that does work, or it is not actionable.
  for (const locale of LOCALES) assert.match(err.message, new RegExp(locale))
})

test("non-locale inputs throw rather than returning something", () => {
  // `__proto__` and `constructor` would resolve on a plain object lookup.
  for (const input of ["__proto__", "constructor", "toString", "", "DE", " de ", null, undefined, 0, {}]) {
    assert.throws(() => getDisclosures(input), { code: "ERR_UNSUPPORTED_LOCALE" },
      `expected ${JSON.stringify(input)} to be rejected`)
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

test("bundles are frozen all the way down", () => {
  const d = getDisclosures("en")
  assert.ok(Object.isFrozen(d))
  assert.ok(Object.isFrozen(d.allergens))
  assert.ok(Object.isFrozen(d.allergens[0]))
  assert.ok(Object.isFrozen(d.declarations[0]))
  assert.ok(Object.isFrozen(d.fallbacks))
})

test("repeated calls are cheap and identical", () => {
  assert.equal(getDisclosures("de"), getDisclosures("de"))
})

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
  for (const locale of ["pt", "nl", "pl", "ru", "de-DE", "DE"]) assert.equal(isLocale(locale), false)
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

test("members of a group share one declaration sentence", () => {
  // The LMIV rendering rule: one declaration per group, members beneath it.
  const { allergens } = getDisclosures("de")
  const byGroup = new Map()
  for (const a of allergens) {
    byGroup.set(a.group, [...(byGroup.get(a.group) ?? []), a])
  }
  for (const [group, members] of byGroup) {
    const sentences = new Set(members.map((m) => m.declaration))
    assert.equal(sentences.size, 1, `${group} has ${sentences.size} different declarations`)
  }
})

test("exported vocabularies are immutable", () => {
  for (const frozen of [LOCALES, ALLERGEN_KEYS, DECLARATION_KEYS, ALLERGEN_GROUPS,
                        DECLARATION_CATEGORIES, ICON_NAMES]) {
    assert.ok(Object.isFrozen(frozen))
  }
  assert.equal(CODE_SCHEME, "MENUELLA")
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
  const svg = getIconSvg("milk", { title: '</title><script>alert(1)</script>' })
  assert.doesNotMatch(svg, /<script>/)
  assert.match(svg, /&lt;script&gt;/)
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
