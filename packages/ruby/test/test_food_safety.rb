# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "menuella/food_safety"

FS = Menuella::FoodSafety

# Behaviour of the published surface, plus the one risk a copied dataset has.
#
# The repository's own validation covers the canonical JSON. What it cannot see
# is whether the copy inside this gem is that JSON — so the tests that read
# ../../data are the ones that matter most here. Without them, a release built
# without running the generator would ship stale disclosures and every other
# assertion would still pass.
class FoodSafetyTest < Minitest::Test
  # Walks up until the canonical dataset is visible, or nil when the tests run
  # from an installed gem rather than the repository.
  def repo_root
    dir = __dir__
    until File.file?(File.join(dir, "data", "allergens.json"))
      parent = File.dirname(dir)
      return nil if parent == dir

      dir = parent
    end
    dir
  end

  def canonical(path)
    root = repo_root or return nil
    JSON.parse(File.read(File.join(root, path), encoding: "UTF-8"))
  end

  # --- Disclosures ---------------------------------------------------------

  def test_every_locale_resolves_to_a_complete_bundle
    FS.locales.each do |locale|
      set = FS.disclosures(locale)
      assert_equal locale, set.locale
      assert_equal FS.fallback_locale, set.fallback_locale
      refute_empty set.allergens, locale
      refute_empty set.declarations, locale

      set.allergens.each do |allergen|
        refute_empty allergen.name, "#{locale}/#{allergen.key}"
        refute_empty allergen.declaration, "#{locale}/#{allergen.key}"
        refute_empty allergen.description, "#{locale}/#{allergen.key}"
      end
      set.declarations.each do |declaration|
        refute_empty declaration.name, "#{locale}/#{declaration.key}"
        refute_empty declaration.icon, "#{locale}/#{declaration.key}"
      end
    end
  end

  def test_german_reads_correctly
    wheat = FS.disclosures("de").allergens.find { _1.key == "WHEAT" }

    assert_equal "Weizen", wheat.name
    assert_equal "Enthält Getreide und glutenhaltige Erzeugnisse", wheat.declaration
    assert_equal "cereals", wheat.icon
    assert_equal "CEREALS", wheat.group
    assert wheat.member?
  end

  def test_an_unsupported_locale_raises_rather_than_falling_back
    error = assert_raises(FS::UnsupportedLocaleError) { FS.disclosures("nl") }

    assert_equal "nl", error.locale
    # The message must name the alternatives, or the caller has to go read the
    # source to find out what is valid.
    assert_includes error.message, "available:"
    assert_includes error.message, "de, en"
    # Rescuable without naming each subclass.
    assert_kind_of FS::Error, error
  end

  def test_everything_returned_is_frozen
    # The dataset is shared state. A caller that could push onto an allergen
    # list, or upcase a declaration in place, would be editing every other
    # caller's copy in the same process.
    set = FS.disclosures("de")
    assert_predicate set, :frozen?
    assert_predicate set.allergens, :frozen?
    assert_predicate set.allergens.first, :frozen?
    assert_predicate set.allergens.first.declaration, :frozen?
    assert_predicate FS.locales, :frozen?
    assert_predicate FS.allergen_keys, :frozen?
    assert_predicate FS.codes.allergens, :frozen?
    assert_predicate FS.icon("milk").nodes.first.attributes, :frozen?

    assert_raises(FrozenError) { FS.disclosures("de").allergens << nil }
  end

  def test_the_same_bundle_is_memoised
    assert_same FS.disclosures("de"), FS.disclosures("de")
    refute_same FS.disclosures("de"), FS.disclosures("en")
  end

  def test_memoisation_survives_concurrent_first_calls
    # allergen_keys memoises a value it computes by calling disclosures, which
    # memoises too. With a plain Mutex that nesting deadlocks; this is the test
    # that would hang rather than fail.
    results = 8.times.map { Thread.new { [FS.allergen_keys, FS.icon_names] } }.map(&:value)
    assert_equal 1, results.uniq.size
  end

  def test_guards_reject_keys_outside_the_vocabulary
    assert FS.allergen_key?("WHEAT")
    assert FS.allergen_key?("EGGS")
    # "EGG" is another vocabulary's word for it, not a key here.
    refute FS.allergen_key?("EGG")

    assert FS.declaration_key?("COLORING")
    refute FS.declaration_key?("WHEAT")

    assert FS.locale?("de")
    refute FS.locale?("nl")
    refute FS.locale?("DE")
  end

  def test_no_duplicate_or_overlapping_keys
    allergens = FS.allergen_keys
    declarations = FS.declaration_keys

    assert_equal allergens.uniq, allergens
    assert_equal declarations.uniq, declarations
    # The two vocabularies must not overlap, or a stored key is ambiguous.
    assert_empty allergens & declarations
  end

  def test_cereals_and_tree_nuts_are_groups_but_never_selectable_keys
    allergens = FS.disclosures("en").allergens
    groups = allergens.map(&:group).uniq
    keys = allergens.map(&:key)

    assert_equal 14, groups.size
    # The law requires naming the specific grain or nut, so the umbrella group
    # is display-only and must not be storable.
    refute_includes keys, "CEREALS"
    refute_includes keys, "TREE_NUTS"
    assert_includes groups, "CEREALS"
    assert_includes groups, "TREE_NUTS"

    allergens.each do |allergen|
      assert_includes groups, allergen.group, allergen.key
      assert_equal allergen.key != allergen.group, allergen.member?, allergen.key
    end
  end

  def test_counts_match_the_canonical_dataset
    assert_equal 28, FS.allergen_keys.size
    assert_equal 22, FS.declaration_keys.size

    {
      "data/allergens.json" => FS.allergen_keys.size,
      "data/declarations.json" => FS.declaration_keys.size,
    }.each do |file, want|
      rows = canonical(file) or next # running outside the repository

      assert_equal want, rows.size, "#{file} drifted — run `npm run generate`"
    end
  end

  def test_packaged_json_is_byte_identical_to_the_canonical_dataset
    root = repo_root or skip "running outside the repository"

    %w[allergens.json declarations.json codes.json icons.json].each do |name|
      expected = File.read(File.join(root, "data", name), encoding: "UTF-8")
      assert_equal expected, FS.dataset(name), "#{name} drifted — run `npm run generate`"
    end

    FS.locales.each do |locale|
      expected = File.read(File.join(root, "data", "bundles", "#{locale}.json"), encoding: "UTF-8")
      assert_equal expected, FS.dataset("bundles/#{locale}"), "#{locale} drifted"
    end
  end

  # --- Codes ---------------------------------------------------------------

  def test_codes_project_keys_onto_printable_codes
    codes = FS.codes

    assert_equal "MENUELLA", codes.scheme
    assert_equal "MENUELLA", FS.code_scheme
    assert_equal "A6", codes.allergens["WHEAT"]
    assert_equal "12", codes.declarations["SWEETENERS"]

    # The two tables are separate, so a key from one must not resolve in the
    # other — a menu that printed "12" for an allergen would be wrong.
    assert_nil codes.allergens["SWEETENERS"]
    assert_nil codes.declarations["WHEAT"]
  end

  def test_every_key_has_exactly_one_code_and_no_code_is_shared
    [[FS.codes.allergens, FS.allergen_keys], [FS.codes.declarations, FS.declaration_keys]].each do |table, keys|
      assert_equal keys.sort, table.keys.sort
      assert_equal table.size, table.values.uniq.size, "two keys share a code"
    end
  end

  # --- Icons ---------------------------------------------------------------

  def test_every_icon_the_data_references_has_a_glyph_and_none_is_unused
    en = FS.disclosures("en")
    referenced = (en.allergens.map(&:icon) + en.declarations.map(&:icon)).uniq

    referenced.each do |name|
      glyph = FS.icon(name)
      refute_empty glyph.nodes, name
      assert_equal "0 0 24 24", glyph.view_box, name
    end

    assert_equal referenced.sort, FS.icon_names,
                 "a rename landed on one side only — run `npm run generate`"
  end

  def test_every_shape_paints_with_current_color
    # Without this a glyph cannot follow the surrounding text colour, which is
    # the whole reason these are inlined rather than shipped as images.
    FS.icon_names.each do |name|
      FS.icon(name).nodes.each do |node|
        assert_equal "currentColor", node.attributes["fill"], "#{name}/#{node.tag}"
      end
    end
  end

  def test_markup_uses_svg_attribute_spelling_not_the_react_one
    all = FS.icon_names.map { FS.icon_to_svg(_1) }.join

    refute_includes all, "fillRule"
    refute_includes all, "clipRule"
    assert_includes all, 'fill-rule="evenodd"'
  end

  def test_svg_is_decorative_by_default_and_named_only_with_a_title
    plain = FS.icon_to_svg("milk")

    assert_includes plain, 'aria-hidden="true"'
    assert_includes plain, 'focusable="false"'
    refute_includes plain, 'role="img"'

    titled = FS.icon_to_svg("milk", title: "Milk")

    assert_includes titled, 'role="img"'
    assert_includes titled, "<title>Milk</title>"
    refute_includes titled, "aria-hidden"
  end

  def test_a_caller_supplied_title_cannot_inject_markup
    svg = FS.icon_to_svg("milk",
                         title: "</title><script>alert(1)</script>",
                         css_class: %("onload="alert(2)))

    refute_includes svg, "<script>"
    assert_includes svg, "&lt;script&gt;"
    # `onload=` still appears as text; what matters is that the quote before it
    # is escaped, so it stays inside the class value instead of opening a new
    # attribute.
    assert_includes svg, 'class="&quot;onload=&quot;alert(2)"'
  end

  def test_a_non_integer_size_cannot_reach_the_markup
    svg = FS.icon_to_svg("milk", size: '16" onload="alert(1)')

    assert_includes svg, 'width="16" height="16"'
    refute_includes svg, "onload"
  end

  def test_markup_is_deterministic
    # Attributes are sorted rather than taken in the order the generator wrote
    # them, so the output does not depend on a JSON key order nobody promised.
    # Unstable markup breaks snapshot tests and any cache keyed on it.
    first = FS.icon_to_svg("eggs")
    20.times { assert_equal first, FS.icon_to_svg("eggs") }
  end

  def test_size_and_class_reach_the_root_element
    svg = FS.icon_to_svg("eggs", size: 16, css_class: "h-4 w-4")

    assert_includes svg, 'width="16" height="16"'
    assert_includes svg, 'class="h-4 w-4"'

    default = FS.icon_to_svg("eggs")

    assert_includes default, 'width="24" height="24"'
    refute_includes default, "class="
  end

  def test_an_unknown_icon_raises
    error = assert_raises(FS::UnknownIconError) { FS.icon("wine") }

    assert_equal "wine", error.name
    assert_includes error.message, "wine"
    assert_raises(FS::UnknownIconError) { FS.icon_to_svg("wine") }
  end

  # --- Packaging -----------------------------------------------------------

  def test_the_version_matches_the_rest_of_the_dataset
    root = repo_root or skip "running outside the repository"
    npm = JSON.parse(File.read(File.join(root, "package.json"), encoding: "UTF-8"))

    assert_equal npm["version"], FS::VERSION,
                 "the gem version and the dataset version have parted ways"
  end
end
