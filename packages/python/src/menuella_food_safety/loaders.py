"""Reading the canonical dataset out of the installed package.

The JSON here is a copy of the repository's ``data/`` — the same bytes the npm
package ships — placed by ``scripts/generate.mjs``. Nothing is transcribed into
Python source: a transcription is a second copy, and a second copy drifts.

Everything is read through :func:`importlib.resources`, not by path arithmetic
off ``__file__``. That is what makes the package work from a zipimport or any
other non-filesystem loader, where ``__file__`` may not point at anything real.
"""

from __future__ import annotations

import json
from functools import lru_cache
from importlib.resources import files
from typing import Any

_DATA = files(__package__).joinpath("data")


def _read(*parts: str) -> Any:
    """Parse one JSON file from the packaged dataset."""
    resource = _DATA
    for part in parts:
        resource = resource.joinpath(part)
    try:
        return json.loads(resource.read_text(encoding="utf-8"))
    except FileNotFoundError as error:  # pragma: no cover - packaging failure
        raise RuntimeError(
            f"Packaged dataset is missing {'/'.join(parts)}. The wheel was built "
            "without its data, which means the build did not run "
            "scripts/generate.mjs first."
        ) from error


@lru_cache(maxsize=None)
def load_bundle(locale: str) -> dict[str, Any]:
    """The raw, pre-joined bundle for one locale."""
    return _read("bundles", f"{locale}.json")


@lru_cache(maxsize=1)
def load_allergens() -> list[dict[str, Any]]:
    """The structural allergen file: keys, groups, icons — no labels."""
    return _read("allergens.json")


@lru_cache(maxsize=1)
def load_declarations() -> list[dict[str, Any]]:
    """The structural declaration file: keys, categories, icons — no labels."""
    return _read("declarations.json")


@lru_cache(maxsize=1)
def load_codes() -> dict[str, Any]:
    """The footnote-code scheme: letters for allergens, numbers for declarations."""
    return _read("codes.json")


@lru_cache(maxsize=1)
def load_icons() -> dict[str, Any]:
    """Every glyph, as ``{name: {viewBox, nodes}}``."""
    return _read("icons.json")


def load_dataset() -> dict[str, Any]:
    """Everything at once, for tooling that wants the raw dataset.

    Prefer :func:`menuella_food_safety.get_disclosures` in application code — it
    returns typed, locale-resolved objects rather than raw JSON.
    """
    return {
        "allergens": load_allergens(),
        "declarations": load_declarations(),
        "codes": load_codes(),
        "icons": load_icons(),
    }
