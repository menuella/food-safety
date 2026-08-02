//! The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens
//! and the Menuella declarations, in six languages.
//!
//! Semantic keys instead of country-specific numbers — store the key, render
//! the code, never the reverse.
//!
//! ```
//! use menuella_food_safety as fs;
//!
//! let de = fs::disclosures("de")?;
//! let wheat = de.allergens.iter().find(|a| a.key == "WHEAT").unwrap();
//! assert_eq!(wheat.declaration, "Enthält Getreide und glutenhaltige Erzeugnisse");
//! # Ok::<(), fs::UnsupportedLocale<'static>>(())
//! ```
//!
//! This crate does **not** do i18n. Hand it the locale your application already
//! resolved; it will not sniff the environment, negotiate, or quietly fall back.
//!
//! # No parsing, no allocation, no dependencies
//!
//! The dataset is generated Rust source, so it lives in the binary's read-only
//! section as `&'static str`. Nothing is parsed at startup, nothing is allocated
//! to read it, and every table is reachable from a `const` context.
//!
//! The standard library has no JSON parser, so reading the data at runtime would
//! have meant depending on `serde_json`. Generating source avoids that.
//!
//! # Optional `serde`
//!
//! Serialization is a consumer concern, so it is behind a feature. Enabling it
//! adds `Serialize` to every data type — handing a bundle to an API response or
//! a template engine:
//!
//! ```toml
//! menuella-food-safety = { version = "1", features = ["serde"] }
//! ```
//!
//! `Deserialize` is deliberately absent. Every field borrows from the binary's
//! static data, so there is nothing to deserialize *into* — and reading this
//! vocabulary back from an untrusted document is exactly the mistake the crate
//! exists to prevent. The dataset in the binary is the authority.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

mod generated;

use std::fmt::{self, Write as _};

/// One allergen, resolved for a locale.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "serde", derive(serde::Serialize))]
pub struct Allergen {
    /// The stored identifier, e.g. `WHEAT`. This is what a product row holds.
    pub key: &'static str,

    /// Its LMIV group, e.g. `CEREALS`.
    ///
    /// `CEREALS` and `TREE_NUTS` are groups but never keys: the law requires
    /// naming the specific grain or nut, so they are display-only.
    pub group: &'static str,

    /// True when this key is one member of a multi-member group.
    pub is_member: bool,

    /// The glyph name, e.g. `cereals`. Pass it to [`icon`].
    pub icon: &'static str,

    /// Short label, e.g. "Wheat".
    pub name: &'static str,

    /// The sentence with legal force. This is what must reach the guest.
    pub declaration: &'static str,

    /// A longer explanation, for tooltips and help text.
    pub description: &'static str,
}

/// One declaration — an additive, beverage or product note — for a locale.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "serde", derive(serde::Serialize))]
pub struct Declaration {
    /// The stored identifier, e.g. `COLORING`.
    pub key: &'static str,

    /// One of `ADDITIVE`, `BEVERAGE`, `WARNING`, `PRODUCT`.
    pub category: &'static str,

    /// The glyph name. Pass it to [`icon`].
    pub icon: &'static str,

    /// Short label, e.g. "With Coloring Agent".
    pub name: &'static str,

    /// A longer explanation.
    pub description: &'static str,
}

/// Every disclosure for one locale, ready to render.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "serde", derive(serde::Serialize))]
pub struct Disclosures {
    /// The locale these entries are resolved for.
    pub locale: &'static str,

    /// The locale this bundle falls back to for anything it does not carry.
    pub fallback_locale: &'static str,

    /// Every allergen, in canonical dataset order.
    pub allergens: &'static [Allergen],

    /// Every declaration, in canonical dataset order.
    pub declarations: &'static [Declaration],
}

/// The footnote-code scheme: letters for allergens, numbers for declarations.
///
/// Codes are what a printed menu shows. Keys are what a database stores, and
/// the projection only runs in that direction — a code is a rendering detail
/// that varies by country, a key is not.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "serde", derive(serde::Serialize))]
pub struct Codes {
    /// The scheme these codes belong to.
    pub scheme: &'static str,

    /// Allergen key to code, e.g. `("WHEAT", "A6")`, in canonical order.
    pub allergens: &'static [(&'static str, &'static str)],

    /// Declaration key to code, e.g. `("SWEETENERS", "12")`, in code order.
    pub declarations: &'static [(&'static str, &'static str)],
}

/// A single shape in a glyph.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "serde", derive(serde::Serialize))]
pub struct IconNode {
    /// The SVG element name, e.g. `path`.
    pub tag: &'static str,

    /// Attribute pairs in SVG spelling (`fill-rule`, not `fillRule`), sorted by
    /// name so rendered markup is byte-stable.
    pub attributes: &'static [(&'static str, &'static str)],
}

/// A glyph as data, for callers that build shapes rather than markup.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "serde", derive(serde::Serialize))]
pub struct Icon {
    /// The coordinate system the shapes are drawn in.
    pub view_box: &'static str,

    /// The shapes to draw, in paint order.
    pub nodes: &'static [IconNode],
}

/// The locale has no bundle. [`LOCALES`] lists the ones that do.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UnsupportedLocale<'a>(
    /// The locale that was asked for.
    pub &'a str,
);

impl fmt::Display for UnsupportedLocale<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "no disclosures for locale {:?} (available: {})",
            self.0,
            LOCALES.join(", ")
        )
    }
}

impl std::error::Error for UnsupportedLocale<'_> {}

/// The name has no glyph. [`ICON_NAMES`] lists the ones that do.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UnknownIcon<'a>(
    /// The icon name that was asked for.
    pub &'a str,
);

impl fmt::Display for UnknownIcon<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "no icon named {:?}", self.0)
    }
}

impl std::error::Error for UnknownIcon<'_> {}

/// Locales with a prebuilt bundle.
pub const LOCALES: &[&str] = generated::LOCALES;

/// The locale a bundle falls back to for anything it does not itself carry.
pub const FALLBACK_LOCALE: &str = generated::FALLBACK_LOCALE;

/// The scheme [`CODES`] belong to.
pub const CODE_SCHEME: &str = generated::CODE_SCHEME;

/// Every selectable allergen key, in canonical order.
///
/// Keys are locale-independent, which is why this is a constant rather than a
/// function taking a locale.
pub const ALLERGEN_KEYS: &[&str] = generated::ALLERGEN_KEYS;

/// Every declaration key, in canonical order.
pub const DECLARATION_KEYS: &[&str] = generated::DECLARATION_KEYS;

/// Every icon name that has a glyph, sorted.
pub const ICON_NAMES: &[&str] = generated::ICON_NAMES;

/// The footnote-code scheme.
pub const CODES: Codes = Codes {
    scheme: generated::CODE_SCHEME,
    allergens: generated::ALLERGEN_CODES,
    declarations: generated::DECLARATION_CODES,
};

/// Every disclosure for `locale`, ready to render.
///
/// Fails rather than falling back: a silently wrong language on an allergen
/// panel is worse than a loud error. The caller knows which locales it supports,
/// and [`is_locale`] is there to ask.
///
/// # Errors
///
/// [`UnsupportedLocale`] when `locale` has no bundle.
pub fn disclosures(locale: &str) -> Result<Disclosures, UnsupportedLocale<'_>> {
    generated::bundle_for(locale).ok_or(UnsupportedLocale(locale))
}

/// Every disclosure for `locale`, usable in a `const` context.
///
/// ```
/// const DE: menuella_food_safety::Disclosures =
///     match menuella_food_safety::disclosures_const("de") {
///         Some(set) => set,
///         None => panic!("de is a supported locale"),
///     };
/// assert_eq!(DE.locale, "de");
/// ```
///
/// Returns `None` rather than an error, because a `const fn` cannot build one.
/// Prefer [`disclosures`] at runtime — its error explains itself.
#[must_use]
pub const fn disclosures_const(locale: &str) -> Option<Disclosures> {
    generated::bundle_for(locale)
}

/// Returns `true` when `value` is a locale with a bundle.
#[must_use]
pub fn is_locale(value: &str) -> bool {
    LOCALES.contains(&value)
}

/// Returns `true` when `value` is a current allergen key. Retired keys and
/// display-only groups return `false`.
#[must_use]
pub fn is_allergen_key(value: &str) -> bool {
    ALLERGEN_KEYS.contains(&value)
}

/// Returns `true` when `value` is a current declaration key.
#[must_use]
pub fn is_declaration_key(value: &str) -> bool {
    DECLARATION_KEYS.contains(&value)
}

/// The printable code for an allergen key, e.g. `WHEAT` → `A6`.
#[must_use]
pub fn allergen_code(key: &str) -> Option<&'static str> {
    lookup(CODES.allergens, key)
}

/// The printable code for a declaration key, e.g. `SWEETENERS` → `12`.
#[must_use]
pub fn declaration_code(key: &str) -> Option<&'static str> {
    lookup(CODES.declarations, key)
}

/// The glyph named `name`, as data.
///
/// Every shape paints with `currentColor`, so a glyph inherits the surrounding
/// text colour and follows a light or dark theme with no second asset.
///
/// # Errors
///
/// [`UnknownIcon`] when `name` has no glyph.
pub fn icon(name: &str) -> Result<Icon, UnknownIcon<'_>> {
    generated::ICONS
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|&(_, icon)| icon)
        .ok_or(UnknownIcon(name))
}

/// How [`icon_to_svg`] renders a glyph.
///
/// ```
/// use menuella_food_safety::SvgOptions;
///
/// let options = SvgOptions { size: Some(16), class: Some("h-4 w-4"), ..Default::default() };
/// ```
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub struct SvgOptions<'a> {
    /// Rendered width and height in px. `None` renders at 24.
    pub size: Option<u32>,

    /// A `class` attribute for the root element.
    pub class: Option<&'a str>,

    /// Gives the glyph an accessible name and `role="img"`.
    ///
    /// Leave this `None` when the declaration text sits beside the icon: the
    /// glyph is then decoration, stays `aria-hidden`, and the text carries the
    /// meaning. On a legal surface that is the correct default, which is why it
    /// is also the free one — render a glyph *alongside* its declaration text,
    /// never instead of it.
    pub title: Option<&'a str>,
}

/// The glyph named `name` as an `<svg>` string, for anything that interpolates
/// markup — server-rendered HTML, e-mail, PDF.
///
/// ```
/// use menuella_food_safety::{icon_to_svg, SvgOptions};
///
/// let svg = icon_to_svg("milk", SvgOptions::default())?;
/// assert!(svg.starts_with("<svg "));
/// assert!(svg.contains(r#"aria-hidden="true""#));
/// # Ok::<(), menuella_food_safety::UnknownIcon<'static>>(())
/// ```
///
/// Attributes are emitted in the order the generator sorted them, so the output
/// is byte-stable across runs and safe to snapshot or cache.
///
/// # Errors
///
/// [`UnknownIcon`] when `name` has no glyph.
pub fn icon_to_svg<'a>(name: &'a str, options: SvgOptions<'_>) -> Result<String, UnknownIcon<'a>> {
    let icon = icon(name)?;
    let size = options.size.unwrap_or(24);

    let mut out = String::with_capacity(512);
    out.push_str(r#"<svg xmlns="http://www.w3.org/2000/svg" viewBox=""#);
    escape_into(&mut out, icon.view_box);
    // Infallible: writing into a String never fails.
    let _ = write!(out, r#"" width="{size}" height="{size}" fill="none""#);

    if let Some(class) = options.class.filter(|value| !value.is_empty()) {
        out.push_str(r#" class=""#);
        escape_into(&mut out, class);
        out.push('"');
    }

    if let Some(title) = options.title.filter(|value| !value.is_empty()) {
        out.push_str(r#" role="img"><title>"#);
        escape_into(&mut out, title);
        out.push_str("</title>");
    } else {
        out.push_str(r#" aria-hidden="true" focusable="false">"#);
    }

    for node in icon.nodes {
        out.push('<');
        out.push_str(node.tag);
        for (key, value) in node.attributes {
            out.push(' ');
            out.push_str(key);
            out.push_str("=\"");
            escape_into(&mut out, value);
            out.push('"');
        }
        out.push_str("/>");
    }

    out.push_str("</svg>");
    Ok(out)
}

fn lookup(table: &'static [(&'static str, &'static str)], key: &str) -> Option<&'static str> {
    table
        .iter()
        .find(|(candidate, _)| *candidate == key)
        .map(|&(_, value)| value)
}

/// The path data is ours, but `icon_to_svg`'s title and class are
/// caller-supplied and land in markup.
fn escape_into(out: &mut String, value: &str) {
    for ch in value.chars() {
        match ch {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            other => out.push(other),
        }
    }
}
