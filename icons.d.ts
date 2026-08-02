import type { IconName } from "./index.js"

/**
 * A single shape: the tag, and its attributes in React naming.
 *
 * The value types are narrow on purpose. `fillRule?: string` would compile here
 * but NOT where it matters — React types `fillRule` as an enum, so a widened
 * string is not assignable to `SVGProps<SVGPathElement>` and every React
 * consumer would need a cast to spread these. Narrow types make the attributes
 * spreadable as-is, which is the entire point of handing out nodes instead of
 * a markup string.
 *
 * `fill` is always `"currentColor"` — the generator rejects anything else,
 * because a shape that cannot inherit the text colour cannot follow a theme.
 */
export type IconNode =
  | [
      "path",
      {
        d: string
        fill: "currentColor"
        fillRule?: "evenodd" | "nonzero"
        clipRule?: "evenodd" | "nonzero"
      },
    ]
  | ["circle", { cx: string; cy: string; r: string; fill: "currentColor" }]

export interface Icon {
  /** Always `"0 0 24 24"`. */
  readonly viewBox: string
  readonly nodes: readonly IconNode[]
}

export interface IconSvgOptions {
  /** Rendered width and height, in px. Default 24. */
  size?: number
  /** Added to the root `<svg>`. */
  className?: string
  /**
   * Gives the glyph an accessible name and `role="img"`.
   *
   * Omit it when the declaration text sits beside the icon: then the glyph is
   * decoration, stays `aria-hidden`, and the text carries the meaning. That is
   * the correct default on a legal surface — an icon must never be the only
   * thing declaring an allergen.
   */
  title?: string
}

/** Icon names that have a glyph. Same set as `ICON_NAMES` in the root export. */
export declare const ICONS_AVAILABLE: readonly IconName[]

/**
 * The glyph as data, for frameworks that build real elements.
 *
 * @throws if the name has no glyph.
 */
export declare function getIcon(name: IconName | (string & {})): Icon

/**
 * The glyph as an `<svg>` string, for templates that interpolate markup.
 *
 * @throws if the name has no glyph.
 */
export declare function getIconSvg(
  name: IconName | (string & {}),
  options?: IconSvgOptions,
): string
