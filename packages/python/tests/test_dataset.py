"""Behaviour of the published surface, plus the one risk a copied dataset has.

The repository's own ``npm run verify`` validates the canonical JSON. What it
cannot see is whether the copy inside *this* package is the same JSON — so the
tests that compare against ``data/`` at the repository root are the ones that
matter most here. Without them, a wheel built without running the generator
would ship stale data and every other test would still pass.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

import menuella_food_safety as fs


def repo_root() -> Path:
    """Walk up until the canonical dataset is visible."""
    for directory in Path(__file__).resolve().parents:
        if (directory / "data" / "allergens.json").is_file():
            return directory
    pytest.skip("canonical data/ not present — running from an installed wheel")


def canonical(*parts: str):
    return json.loads((repo_root().joinpath(*parts)).read_text(encoding="utf-8"))


# --------------------------------------------------------------- the dataset --


def test_every_locale_resolves_to_a_complete_bundle():
    for locale in fs.LOCALES:
        disclosures = fs.get_disclosures(locale)
        assert disclosures.locale == locale
        assert disclosures.allergens
        assert disclosures.declarations
        for allergen in disclosures.allergens:
            assert allergen.declaration, f"{locale}/{allergen.key}"
            assert allergen.name, f"{locale}/{allergen.key}"


def test_an_unknown_locale_raises_rather_than_falling_back():
    with pytest.raises(ValueError, match="Available:"):
        fs.get_disclosures("nope")


def test_the_same_object_is_returned_each_time():
    # Cached: re-parsing per call would be a silent allocation on a hot path.
    assert fs.get_disclosures("de") is fs.get_disclosures("de")


def test_entries_are_immutable():
    # The dataset is a process-wide singleton; a caller who mutated one entry
    # would corrupt it for everyone else.
    allergen = fs.get_disclosures("en").allergens[0]
    with pytest.raises(Exception):
        allergen.key = "TAMPERED"  # type: ignore[misc]


def test_guards_reject_keys_outside_the_vocabulary():
    assert fs.is_allergen_key("WHEAT")
    assert fs.is_allergen_key("EGGS")
    # "EGG" is another vocabulary's word for it, not a key here.
    assert not fs.is_allergen_key("EGG")
    assert fs.is_declaration_key("COLORING")
    assert not fs.is_declaration_key("WHEAT")
    assert not fs.is_allergen_key(None)
    assert not fs.is_locale(42)


def test_no_duplicate_keys():
    assert len(set(fs.ALLERGEN_KEYS)) == len(fs.ALLERGEN_KEYS)
    assert len(set(fs.DECLARATION_KEYS)) == len(fs.DECLARATION_KEYS)
    # The two vocabularies must not overlap, or a stored key would be ambiguous.
    assert not set(fs.ALLERGEN_KEYS) & set(fs.DECLARATION_KEYS)


def test_cereals_and_tree_nuts_are_groups_but_never_selectable_keys():
    english = fs.get_disclosures("en")
    groups = {a.group for a in english.allergens}
    keys = {a.key for a in english.allergens}

    assert len(groups) == 14
    # The law requires naming the specific grain or nut, so the umbrella group
    # is display-only and must not be storable.
    assert "CEREALS" not in keys
    assert "TREE_NUTS" not in keys
    assert {"CEREALS", "TREE_NUTS"} <= groups


# ------------------------------------------- the copy matches the canonical --


def test_key_counts_match_the_canonical_dataset():
    assert len(fs.ALLERGEN_KEYS) == len(canonical("data", "allergens.json")) == 28
    assert len(fs.DECLARATION_KEYS) == len(canonical("data", "declarations.json")) == 22
    assert fs.CODE_SCHEME == canonical("data", "codes.json")["scheme"] == "MENUELLA"


def test_packaged_json_is_byte_identical_to_the_canonical_dataset():
    packaged = Path(fs.__file__).parent / "data"
    for name in ("allergens.json", "declarations.json", "codes.json", "icons.json"):
        assert (packaged / name).read_bytes() == (
            repo_root() / "data" / name
        ).read_bytes(), f"{name} drifted — run `npm run generate`"


def test_version_matches_the_repository():
    root = json.loads((repo_root() / "package.json").read_text(encoding="utf-8"))
    import tomllib

    pyproject = tomllib.loads(
        (repo_root() / "packages" / "python" / "pyproject.toml").read_text("utf-8")
    )
    assert pyproject["project"]["version"] == root["version"], (
        "pyproject.toml and package.json disagree — all bindings ship one "
        "version from one tag"
    )


def test_the_dataset_validates_against_its_own_schemas():
    jsonschema = pytest.importorskip("jsonschema")
    for data_file, schema_file in (
        ("allergens.json", "allergen.schema.json"),
        ("declarations.json", "declaration.schema.json"),
    ):
        # The schema describes the whole array (type: array, items: …), not a
        # single entry — validating per-entry silently checks the wrong thing.
        jsonschema.validate(
            canonical("data", data_file), canonical("schemas", schema_file)
        )


# ----------------------------------------------------------------- the icons --


def test_every_icon_the_data_references_has_a_glyph():
    english = fs.get_disclosures("en")
    referenced = {a.icon for a in english.allergens} | {
        d.icon for d in english.declarations
    }
    for name in referenced:
        assert fs.get_icon(name).nodes, name
    # And no glyph is unreferenced — dead weight usually means a half-rename.
    assert referenced == set(fs.ICON_NAMES)


def test_every_shape_paints_with_current_color():
    # Without this a glyph cannot follow the surrounding text colour, which is
    # the whole reason these are inlined rather than served as images.
    for name in fs.ICON_NAMES:
        for node in fs.get_icon(name).nodes:
            assert dict(node.attributes).get("fill") == "currentColor", (
                f"{name}/{node.tag}"
            )


def test_markup_uses_svg_attribute_spelling_not_the_react_one():
    everything = "".join(fs.icon_to_svg(name) for name in fs.ICON_NAMES)
    assert "fillRule" not in everything
    assert "clipRule" not in everything
    assert 'fill-rule="evenodd"' in everything


def test_svg_is_decorative_by_default_and_named_only_with_a_title():
    plain = fs.icon_to_svg("milk")
    assert 'aria-hidden="true"' in plain
    assert 'focusable="false"' in plain
    assert 'role="img"' not in plain

    titled = fs.icon_to_svg("milk", title="Milk")
    assert 'role="img"' in titled
    assert "<title>Milk</title>" in titled
    assert "aria-hidden" not in titled


def test_a_caller_supplied_title_cannot_inject_markup():
    svg = fs.icon_to_svg("milk", title="</title><script>alert(1)</script>")
    assert "<script>" not in svg
    assert "&lt;script&gt;" in svg


def test_size_and_class_reach_the_root_element():
    svg = fs.icon_to_svg("eggs", size=16, css_class="h-4 w-4")
    assert 'width="16" height="16"' in svg
    assert 'class="h-4 w-4"' in svg


def test_an_unknown_icon_raises_and_names_what_is_available():
    with pytest.raises(ValueError, match="Available:"):
        fs.get_icon("wine")
