"""Open allergen and additive vocabulary for restaurant menus.

EU Reg. 1169/2011 Annex II allergens and the Menuella declarations, in six
languages. Semantic keys instead of country-specific numbers — store the key,
render the code, never the reverse.

    >>> from menuella_food_safety import get_disclosures
    >>> de = get_disclosures("de")
    >>> next(a for a in de.allergens if a.key == "WHEAT").declaration
    'Enthält Getreide und glutenhaltige Erzeugnisse'

This package does **not** do i18n. Hand it the locale your app already resolved;
it will not sniff, negotiate, or quietly fall back.
"""

from __future__ import annotations

from functools import lru_cache
from html import escape as _escape

from ._models import Allergen, Declaration, Disclosures, Icon, IconNode
from .loaders import (
    load_allergens,
    load_bundle,
    load_codes,
    load_dataset,
    load_declarations,
    load_icons,
)

__all__ = [
    "ALLERGEN_KEYS",
    "CODE_SCHEME",
    "DECLARATION_KEYS",
    "FALLBACK_LOCALE",
    "ICON_NAMES",
    "LOCALES",
    "Allergen",
    "Declaration",
    "Disclosures",
    "Icon",
    "IconNode",
    "__version__",
    "get_disclosures",
    "get_icon",
    "icon_to_svg",
    "is_allergen_key",
    "is_declaration_key",
    "is_locale",
    "load_dataset",
]

try:  # pragma: no cover - trivial
    from importlib.metadata import version as _version

    __version__ = _version("menuella-food-safety")
except Exception:  # pragma: no cover - running from a source tree
    __version__ = "0.0.0+unknown"

LOCALES: tuple[str, ...] = ("de", "en", "es", "fr", "it", "tr")
"""Locales with a prebuilt bundle."""

FALLBACK_LOCALE = "en"
"""The locale a bundle falls back to for anything it does not itself carry."""

CODE_SCHEME: str = load_codes()["scheme"]
"""The footnote-code scheme these codes belong to."""

ALLERGEN_KEYS: tuple[str, ...] = tuple(a["key"] for a in load_allergens())
"""Every selectable allergen key, in canonical order. Derived, never hand-listed."""

DECLARATION_KEYS: tuple[str, ...] = tuple(d["key"] for d in load_declarations())
"""Every declaration key, in canonical order."""

ICON_NAMES: tuple[str, ...] = tuple(sorted(load_icons()))
"""Every icon name that has a glyph."""

_ALLERGENS = frozenset(ALLERGEN_KEYS)
_DECLARATIONS = frozenset(DECLARATION_KEYS)
_LOCALES = frozenset(LOCALES)

# The JSON carries React attribute spelling, because its first consumer is
# React. Markup needs the SVG one, and an unmapped name still *draws* — just
# without the even-odd rule — so the bug would be a subtly wrong glyph rather
# than a missing one.
_SVG_ATTRIBUTE = {"fillRule": "fill-rule", "clipRule": "clip-rule"}


def is_locale(value: object) -> bool:
    """True when ``value`` is a locale with a bundle."""
    return isinstance(value, str) and value in _LOCALES


def is_allergen_key(value: object) -> bool:
    """True when ``value`` is a current allergen key. Retired keys return False."""
    return isinstance(value, str) and value in _ALLERGENS


def is_declaration_key(value: object) -> bool:
    """True when ``value`` is a current declaration key."""
    return isinstance(value, str) and value in _DECLARATIONS


@lru_cache(maxsize=None)
def get_disclosures(locale: str) -> Disclosures:
    """Every disclosure for ``locale``, ready to render.

    Raises :class:`ValueError` if the locale has no bundle. It raises rather
    than falling back because a silently wrong language on an allergen panel is
    worse than a loud failure — the caller knows which locales it supports, and
    :func:`is_locale` is there to ask.
    """
    if not is_locale(locale):
        raise ValueError(
            f"No disclosures for locale {locale!r}. Available: {', '.join(LOCALES)}."
        )

    bundle = load_bundle(locale)
    return Disclosures(
        locale=bundle["locale"],
        fallback_locale=bundle["fallbackLocale"],
        allergens=tuple(
            Allergen(
                key=a["key"],
                group=a["group"],
                is_member=a["isMember"],
                icon=a["icon"],
                name=a["name"],
                declaration=a["declaration"],
                description=a["description"],
            )
            for a in bundle["allergens"]
        ),
        declarations=tuple(
            Declaration(
                key=d["key"],
                category=d["category"],
                icon=d["icon"],
                name=d["name"],
                description=d["description"],
            )
            for d in bundle["declarations"]
        ),
    )


@lru_cache(maxsize=None)
def get_icon(name: str) -> Icon:
    """The glyph named ``name``, as data.

    Every shape paints with ``currentColor``, so a glyph inherits the
    surrounding text colour and follows a light/dark theme with no second asset.

    Raises :class:`ValueError` if the name has no glyph.
    """
    raw = load_icons().get(name)
    if raw is None:
        raise ValueError(
            f"No icon named {name!r}. Available: {', '.join(ICON_NAMES)}."
        )

    return Icon(
        view_box=raw["viewBox"],
        nodes=tuple(
            IconNode(
                tag=tag,
                attributes=tuple(
                    (_SVG_ATTRIBUTE.get(key, key), value)
                    for key, value in attributes.items()
                ),
            )
            for tag, attributes in raw["nodes"]
        ),
    )


def icon_to_svg(
    name: str,
    *,
    size: int = 24,
    css_class: str | None = None,
    title: str | None = None,
) -> str:
    """The glyph named ``name`` as an ``<svg>`` string.

    For templates that interpolate markup — Jinja, e-mail, PDF.

    Decorative by default: emits ``aria-hidden`` unless ``title`` is given,
    which switches it to ``role="img"`` with a ``<title>``. These glyphs carry
    legal meaning, so the safe default is the free one: render one *alongside*
    its declaration text, never instead of it.

    Raises :class:`ValueError` if the name has no glyph.
    """
    icon = get_icon(name)

    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg"',
        f' viewBox="{_escape(icon.view_box, quote=True)}"',
        f' width="{size}" height="{size}" fill="none"',
    ]
    if css_class:
        parts.append(f' class="{_escape(css_class, quote=True)}"')

    if title:
        parts.append(f' role="img"><title>{_escape(title)}</title>')
    else:
        parts.append(' aria-hidden="true" focusable="false">')

    for node in icon.nodes:
        attributes = "".join(
            f' {key}="{_escape(value, quote=True)}"' for key, value in node.attributes
        )
        parts.append(f"<{node.tag}{attributes}/>")

    parts.append("</svg>")
    return "".join(parts)
