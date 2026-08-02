//! Behaviour of the published surface, plus the one risk a generated copy has.
//!
//! The repository's own validation covers the canonical JSON. What it cannot see
//! is whether `src/generated.rs` is still that JSON — so the tests that read
//! `data/` are the ones that matter most here. Without them, a release cut
//! without running the generator would ship stale disclosures and every other
//! assertion would still pass.

use std::collections::HashSet;
use std::path::PathBuf;

use menuella_food_safety as fs;

/// Walks up until the canonical dataset is visible, or `None` when the tests are
/// running from a downloaded crate rather than the repository.
fn repo_root() -> Option<PathBuf> {
    let mut dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    loop {
        if dir.join("data/allergens.json").is_file() {
            return Some(dir);
        }
        if !dir.pop() {
            return None;
        }
    }
}

fn canonical(path: &str) -> Option<serde_json::Value> {
    let raw = std::fs::read_to_string(repo_root()?.join(path)).expect("canonical file is readable");
    Some(serde_json::from_str(&raw).expect("canonical file is JSON"))
}

// MARK: - Disclosures

#[test]
fn every_locale_resolves_to_a_complete_bundle() {
    for locale in fs::LOCALES {
        let set = fs::disclosures(locale).expect("listed locale resolves");
        assert_eq!(set.locale, *locale);
        assert_eq!(set.fallback_locale, fs::FALLBACK_LOCALE);
        assert!(!set.allergens.is_empty(), "{locale}: no allergens");
        assert!(!set.declarations.is_empty(), "{locale}: no declarations");

        for allergen in set.allergens {
            assert!(!allergen.name.is_empty(), "{locale}/{}", allergen.key);
            assert!(
                !allergen.declaration.is_empty(),
                "{locale}/{}",
                allergen.key
            );
            assert!(
                !allergen.description.is_empty(),
                "{locale}/{}",
                allergen.key
            );
        }
        for declaration in set.declarations {
            assert!(!declaration.name.is_empty(), "{locale}/{}", declaration.key);
            assert!(!declaration.icon.is_empty(), "{locale}/{}", declaration.key);
        }
    }
}

#[test]
fn german_reads_correctly() {
    let de = fs::disclosures("de").unwrap();
    let wheat = de
        .allergens
        .iter()
        .find(|a| a.key == "WHEAT")
        .expect("WHEAT is in every bundle");

    assert_eq!(wheat.name, "Weizen");
    assert_eq!(
        wheat.declaration,
        "Enthält Getreide und glutenhaltige Erzeugnisse"
    );
    assert_eq!(wheat.icon, "cereals");
    assert_eq!(wheat.group, "CEREALS");
    assert!(wheat.is_member);
}

#[test]
fn an_unsupported_locale_errors_rather_than_falling_back() {
    let error = fs::disclosures("nl").expect_err("nl has no bundle");
    assert_eq!(error, fs::UnsupportedLocale("nl"));

    // The message must name the alternatives, or the caller has to go read the
    // source to find out what is valid.
    let text = error.to_string();
    assert!(text.contains("available:"), "{text}");
    assert!(text.contains("de, en"), "{text}");
}

#[test]
fn a_bundle_is_usable_in_a_const_context() {
    // The whole point of generating source rather than parsing JSON. If this
    // ever stops compiling, the crate has quietly become a runtime-init crate.
    const DE: fs::Disclosures = match fs::disclosures_const("de") {
        Some(set) => set,
        None => panic!("de is a supported locale"),
    };

    assert_eq!(DE.locale, "de");
    assert!(fs::disclosures_const("nl").is_none());

    // A two-byte comparison must not match a longer string that starts the same.
    assert!(fs::disclosures_const("den").is_none());
    assert!(fs::disclosures_const("d").is_none());
    assert!(fs::disclosures_const("").is_none());
}

#[test]
fn guards_reject_keys_outside_the_vocabulary() {
    assert!(fs::is_allergen_key("WHEAT"));
    assert!(fs::is_allergen_key("EGGS"));
    // "EGG" is another vocabulary's word for it, not a key here.
    assert!(!fs::is_allergen_key("EGG"));

    assert!(fs::is_declaration_key("COLORING"));
    assert!(!fs::is_declaration_key("WHEAT"));

    assert!(fs::is_locale("de"));
    assert!(!fs::is_locale("nl"));
    assert!(!fs::is_locale("DE"));
}

#[test]
fn no_duplicate_or_overlapping_keys() {
    let allergens: HashSet<_> = fs::ALLERGEN_KEYS.iter().collect();
    let declarations: HashSet<_> = fs::DECLARATION_KEYS.iter().collect();

    assert_eq!(allergens.len(), fs::ALLERGEN_KEYS.len());
    assert_eq!(declarations.len(), fs::DECLARATION_KEYS.len());
    // The two vocabularies must not overlap, or a stored key is ambiguous.
    assert!(allergens.is_disjoint(&declarations));
}

#[test]
fn cereals_and_tree_nuts_are_groups_but_never_selectable_keys() {
    let en = fs::disclosures("en").unwrap();
    let groups: HashSet<_> = en.allergens.iter().map(|a| a.group).collect();
    let keys: HashSet<_> = en.allergens.iter().map(|a| a.key).collect();

    assert_eq!(groups.len(), 14);
    // The law requires naming the specific grain or nut, so the umbrella group
    // is display-only and must not be storable.
    assert!(!keys.contains("CEREALS"));
    assert!(!keys.contains("TREE_NUTS"));
    assert!(groups.contains("CEREALS") && groups.contains("TREE_NUTS"));

    // Every group that is not one of those two is also a key, and every member
    // belongs to a group that exists.
    for allergen in en.allergens {
        assert!(groups.contains(allergen.group), "{}", allergen.key);
        assert_eq!(
            allergen.is_member,
            allergen.key != allergen.group,
            "{}",
            allergen.key
        );
    }
}

#[test]
fn counts_match_the_canonical_dataset() {
    assert_eq!(fs::ALLERGEN_KEYS.len(), 28);
    assert_eq!(fs::DECLARATION_KEYS.len(), 22);

    for (file, want) in [
        ("data/allergens.json", fs::ALLERGEN_KEYS.len()),
        ("data/declarations.json", fs::DECLARATION_KEYS.len()),
    ] {
        let Some(rows) = canonical(file) else {
            continue; // running outside the repository
        };
        assert_eq!(
            rows.as_array().expect("an array").len(),
            want,
            "{file} drifted — run `npm run generate`"
        );
    }
}

#[test]
fn generated_source_matches_the_canonical_bundles() {
    for locale in fs::LOCALES {
        let Some(bundle) = canonical(&format!("data/bundles/{locale}.json")) else {
            continue; // running outside the repository
        };
        let set = fs::disclosures(locale).unwrap();

        let allergens = bundle["allergens"].as_array().expect("an array");
        assert_eq!(allergens.len(), set.allergens.len(), "{locale}");
        for (want, got) in allergens.iter().zip(set.allergens) {
            assert_eq!(want["key"], got.key, "{locale}");
            assert_eq!(want["group"], got.group, "{locale}/{}", got.key);
            assert_eq!(want["isMember"], got.is_member, "{locale}/{}", got.key);
            assert_eq!(want["icon"], got.icon, "{locale}/{}", got.key);
            assert_eq!(want["name"], got.name, "{locale}/{}", got.key);
            assert_eq!(want["declaration"], got.declaration, "{locale}/{}", got.key);
            assert_eq!(want["description"], got.description, "{locale}/{}", got.key);
        }

        let declarations = bundle["declarations"].as_array().expect("an array");
        assert_eq!(declarations.len(), set.declarations.len(), "{locale}");
        for (want, got) in declarations.iter().zip(set.declarations) {
            assert_eq!(want["key"], got.key, "{locale}");
            assert_eq!(want["category"], got.category, "{locale}/{}", got.key);
            assert_eq!(want["icon"], got.icon, "{locale}/{}", got.key);
            assert_eq!(want["name"], got.name, "{locale}/{}", got.key);
            assert_eq!(want["description"], got.description, "{locale}/{}", got.key);
        }
    }
}

// MARK: - Codes

#[test]
fn codes_project_keys_onto_printable_codes() {
    assert_eq!(fs::CODE_SCHEME, "MENUELLA");
    assert_eq!(fs::CODES.scheme, "MENUELLA");
    assert_eq!(fs::allergen_code("WHEAT"), Some("A6"));
    assert_eq!(fs::declaration_code("SWEETENERS"), Some("12"));

    // The two tables are separate, so a key from one must not resolve in the
    // other — a menu that printed "12" for an allergen would be wrong.
    assert_eq!(fs::allergen_code("SWEETENERS"), None);
    assert_eq!(fs::declaration_code("WHEAT"), None);
    assert_eq!(fs::allergen_code("NOT_A_KEY"), None);
}

#[test]
fn every_key_has_exactly_one_code_and_no_code_is_shared() {
    for (table, keys) in [
        (fs::CODES.allergens, fs::ALLERGEN_KEYS),
        (fs::CODES.declarations, fs::DECLARATION_KEYS),
    ] {
        assert_eq!(table.len(), keys.len());
        let with_a_code: HashSet<_> = table.iter().map(|(key, _)| *key).collect();
        let expected: HashSet<_> = keys.iter().copied().collect();
        assert_eq!(with_a_code, expected);

        let distinct: HashSet<_> = table.iter().map(|(_, code)| *code).collect();
        assert_eq!(distinct.len(), table.len(), "two keys share a code");
    }
}

// MARK: - Icons

#[test]
fn every_icon_the_data_references_has_a_glyph_and_none_is_unused() {
    let en = fs::disclosures("en").unwrap();
    let referenced: HashSet<_> = en
        .allergens
        .iter()
        .map(|a| a.icon)
        .chain(en.declarations.iter().map(|d| d.icon))
        .collect();

    for name in &referenced {
        let icon = fs::icon(name).unwrap_or_else(|_| panic!("{name} has no glyph"));
        assert!(!icon.nodes.is_empty(), "{name}");
        assert_eq!(icon.view_box, "0 0 24 24", "{name}");
    }

    let published: HashSet<_> = fs::ICON_NAMES.iter().copied().collect();
    assert_eq!(
        published, referenced,
        "a rename landed on one side only — run `npm run generate`"
    );
}

#[test]
fn icon_names_is_sorted_and_matches_the_lookup_table() {
    let mut sorted = fs::ICON_NAMES.to_vec();
    sorted.sort_unstable();
    assert_eq!(sorted, fs::ICON_NAMES);

    for name in fs::ICON_NAMES {
        assert!(fs::icon(name).is_ok(), "{name}");
    }
}

#[test]
fn every_shape_paints_with_current_color() {
    // Without this a glyph cannot follow the surrounding text colour, which is
    // the whole reason these are inlined rather than shipped as images.
    for name in fs::ICON_NAMES {
        for node in fs::icon(name).unwrap().nodes {
            let fill = node
                .attributes
                .iter()
                .find(|(key, _)| *key == "fill")
                .map(|(_, value)| *value);
            assert_eq!(fill, Some("currentColor"), "{name}/{}", node.tag);
        }
    }
}

#[test]
fn markup_uses_svg_attribute_spelling_not_the_react_one() {
    let all: String = fs::ICON_NAMES
        .iter()
        .map(|name| fs::icon_to_svg(name, fs::SvgOptions::default()).unwrap())
        .collect();

    assert!(!all.contains("fillRule"));
    assert!(!all.contains("clipRule"));
    assert!(all.contains(r#"fill-rule="evenodd""#));
}

#[test]
fn svg_is_decorative_by_default_and_named_only_with_a_title() {
    let plain = fs::icon_to_svg("milk", fs::SvgOptions::default()).unwrap();
    assert!(plain.contains(r#"aria-hidden="true""#));
    assert!(plain.contains(r#"focusable="false""#));
    assert!(!plain.contains(r#"role="img""#));

    let titled = fs::icon_to_svg(
        "milk",
        fs::SvgOptions {
            title: Some("Milk"),
            ..Default::default()
        },
    )
    .unwrap();
    assert!(titled.contains(r#"role="img""#));
    assert!(titled.contains("<title>Milk</title>"));
    assert!(!titled.contains("aria-hidden"));
}

#[test]
fn a_caller_supplied_title_cannot_inject_markup() {
    let svg = fs::icon_to_svg(
        "milk",
        fs::SvgOptions {
            title: Some("</title><script>alert(1)</script>"),
            class: Some(r#""onload="alert(2)"#),
            ..Default::default()
        },
    )
    .unwrap();

    assert!(!svg.contains("<script>"));
    assert!(svg.contains("&lt;script&gt;"));

    // `onload=` still appears as text — what matters is that the quote before it
    // is escaped, so it stays inside the class value instead of becoming a new
    // attribute.
    assert!(
        svg.contains(r#"class="&quot;onload=&quot;alert(2)""#),
        "{svg}"
    );
}

#[test]
fn markup_is_deterministic() {
    // Attributes are sorted by the generator rather than iterated from a map, so
    // the output is stable run to run — snapshot tests and any cache keyed on the
    // markup depend on it.
    let first = fs::icon_to_svg("eggs", fs::SvgOptions::default()).unwrap();
    for _ in 0..20 {
        assert_eq!(
            fs::icon_to_svg("eggs", fs::SvgOptions::default()).unwrap(),
            first
        );
    }
}

#[test]
fn size_and_class_reach_the_root_element() {
    let svg = fs::icon_to_svg(
        "eggs",
        fs::SvgOptions {
            size: Some(16),
            class: Some("h-4 w-4"),
            title: None,
        },
    )
    .unwrap();

    assert!(svg.contains(r#"width="16" height="16""#));
    assert!(svg.contains(r#"class="h-4 w-4""#));

    // The default is 24, not zero or absent.
    let default = fs::icon_to_svg("eggs", fs::SvgOptions::default()).unwrap();
    assert!(default.contains(r#"width="24" height="24""#));
    assert!(!default.contains("class="));
}

#[test]
fn an_unknown_icon_errors() {
    let error = fs::icon("wine").expect_err("wine has no glyph");
    assert_eq!(error, fs::UnknownIcon("wine"));
    assert!(error.to_string().contains("wine"));
    assert!(fs::icon_to_svg("wine", fs::SvgOptions::default()).is_err());
}

// MARK: - serde

#[cfg(feature = "serde")]
#[test]
fn a_bundle_serializes_to_the_shape_the_dataset_publishes() {
    let de = fs::disclosures("de").unwrap();
    let json: serde_json::Value = serde_json::from_str(&serde_json::to_string(&de).unwrap())
        .expect("the bundle round-trips through JSON");

    assert_eq!(json["locale"], "de");
    // Rust spells these with underscores; the field names follow the struct, not
    // the canonical JSON. Asserted so the difference is a decision, not a
    // surprise for anyone diffing the two.
    assert_eq!(json["fallback_locale"], "en");
    assert_eq!(json["allergens"].as_array().unwrap().len(), 28);
    assert_eq!(json["allergens"][0]["is_member"], true);
}
