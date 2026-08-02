"""The shapes the public API hands back.

Frozen dataclasses rather than dicts: the dataset is a shared singleton, and a
caller who mutated one entry would corrupt it for every other caller in the
process. Frozen also makes them hashable, so they work as dict keys and set
members without a copy.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Allergen:
    """One allergen, resolved for a locale."""

    key: str
    """The stored identifier, e.g. ``WHEAT``. This is what a product row holds."""

    group: str
    """Its LMIV group, e.g. ``CEREALS``.

    Twelve groups are also selectable keys; ``CEREALS`` and ``TREE_NUTS`` are
    display-only, because the law requires naming the specific grain or nut.
    """

    is_member: bool
    """True when this key is one member of a multi-member group."""

    icon: str
    """The glyph name, e.g. ``cereals``."""

    name: str
    """Short label, e.g. "Wheat"."""

    declaration: str
    """The sentence with legal force. This is what must reach the guest."""

    description: str
    """A longer explanation, for tooltips and help text."""


@dataclass(frozen=True, slots=True)
class Declaration:
    """One declaration — an additive, beverage or product note — for a locale."""

    key: str
    """The stored identifier, e.g. ``COLORING``."""

    category: str
    """One of ``ADDITIVE``, ``BEVERAGE``, ``WARNING``, ``PRODUCT``."""

    icon: str
    """The glyph name. All declarations share one generic glyph."""

    name: str
    """Short label, e.g. "With Coloring Agent"."""

    description: str
    """A longer explanation."""


@dataclass(frozen=True, slots=True)
class Disclosures:
    """Every disclosure for one locale, ready to render."""

    locale: str
    fallback_locale: str
    allergens: tuple[Allergen, ...]
    declarations: tuple[Declaration, ...]


@dataclass(frozen=True, slots=True)
class IconNode:
    """A single shape in a glyph: the tag, and its SVG attributes."""

    tag: str
    """``path`` or ``circle``."""

    attributes: tuple[tuple[str, str], ...]
    """Attribute pairs in SVG spelling (``fill-rule``, not ``fillRule``).

    A tuple of pairs rather than a dict, so the dataclass stays hashable and
    genuinely immutable — a frozen dataclass holding a dict is neither.
    """


@dataclass(frozen=True, slots=True)
class Icon:
    """A glyph as data, for callers that build elements rather than markup."""

    view_box: str
    """Always ``"0 0 24 24"``."""

    nodes: tuple[IconNode, ...]
