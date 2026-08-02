// The 15 disclosure glyphs. Hand-written; the path data it imports is
// generated from icons/*.svg by scripts/generate.mjs.
//
// Every shape paints with `currentColor`, so a glyph inherits the surrounding
// text colour and follows a light/dark theme with no prop, no second asset and
// no duplicated palette. That is the whole reason these are inlined rather
// than served as <img>: an <img> cannot inherit colour.
//
// Two shapes, because consumers genuinely differ:
//
//   getIcon(name)      → { viewBox, nodes } for frameworks that build real
//                        elements (React, Svelte, Vue). No innerHTML.
//   getIconSvg(name)   → an <svg> string for templates that interpolate markup
//                        (Astro `set:html`, e-mail, PDF).
//
// Deliberately NOT a React component: this package has no framework in its
// dependency list and is consumed from both Astro and React inside Menuella
// alone. A component would pick a winner and add a peer dependency.
//
// ACCESSIBILITY. These glyphs carry legal meaning ("contains wheat"). Render
// them ALONGSIDE the declaration text, never instead of it. They are therefore
// decorative by default — `getIconSvg` emits `aria-hidden` unless you pass a
// `title`, and `getIcon` callers should do the same.

import ICON_DATA from "./data/icons.js"

/** Icon names that have a glyph. Same set as `ICON_NAMES` in the root export. */
export const ICONS_AVAILABLE = Object.freeze(Object.keys(ICON_DATA))

/**
 * Icons are module-level singletons shared by every caller, so a consumer that
 * mutated one would corrupt the glyph for the whole process. Frozen on first
 * access rather than at module scope, for the same reason the bundles are: a
 * top-level call is an impure statement and stops bundlers tree-shaking the
 * path data away for consumers that never ask for an icon.
 */
const deepFreeze = (value) => {
  if (value !== null && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value)
    for (const inner of Object.values(value)) deepFreeze(inner)
  }
  return value
}

/**
 * The glyph as data: `{ viewBox, nodes }`, where each node is
 * `[tag, attributes]` with React-style attribute names (`fillRule`).
 *
 * @throws if the name has no glyph.
 */
export function getIcon(name) {
  const icon = Object.hasOwn(ICON_DATA, name) ? ICON_DATA[name] : undefined
  if (icon === undefined) {
    const error = new Error(
      `No icon named "${name}". Available: ${ICONS_AVAILABLE.join(", ")}.`,
    )
    error.code = "ERR_UNKNOWN_ICON"
    throw error
  }
  return deepFreeze(icon)
}

// SVG attribute names are hyphenated; the data carries the React spelling.
const SVG_ATTR = { fillRule: "fill-rule", clipRule: "clip-rule" }

// The values are our own path data, but the title is caller-supplied and lands
// in markup, so it is escaped. `"` and `'` too: a title is interpolated into an
// attribute nowhere here, but this function's output is often pasted into one.
const escape = (value) =>
  String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")

/**
 * The glyph as an `<svg>` string, for templates that interpolate markup.
 *
 * @throws if the name has no glyph.
 */
export function getIconSvg(name, options = {}) {
  const { size = 24, className, title } = options
  const icon = getIcon(name)

  const children = icon.nodes
    .map(([tag, attrs]) => {
      const pairs = Object.entries(attrs)
        .map(([key, value]) => `${SVG_ATTR[key] ?? key}="${escape(value)}"`)
        .join(" ")
      return `<${tag} ${pairs}/>`
    })
    .join("")

  // A title makes the glyph its own accessible element. Without one it is
  // decoration beside text that already carries the meaning — which is the
  // correct default on a legal surface, so it is what you get for free.
  const a11y = title
    ? `role="img"><title>${escape(title)}</title>`
    : `aria-hidden="true" focusable="false">`

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${icon.viewBox}"` +
    ` width="${size}" height="${size}" fill="none"` +
    (className ? ` class="${escape(className)}"` : "") +
    ` ${a11y}${children}</svg>`
  )
}
