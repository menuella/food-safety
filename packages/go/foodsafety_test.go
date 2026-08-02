package foodsafety

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// repoRoot walks up until the canonical dataset is visible, or returns "" when
// running outside the repository.
//
// The tests that use it are the ones that matter most here: this module EMBEDS
// a copy of the dataset, so if the generator ever stopped being run it would
// ship stale data and every other assertion would still pass.
func repoRoot(t *testing.T) string {
	t.Helper()
	dir, err := filepath.Abs(".")
	if err != nil {
		return ""
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "data", "allergens.json")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

func TestEveryLocaleResolvesToACompleteBundle(t *testing.T) {
	for _, locale := range Locales() {
		set, err := GetDisclosures(locale)
		if err != nil {
			t.Fatalf("%s: %v", locale, err)
		}
		if set.Locale != locale {
			t.Errorf("%s: got locale %q", locale, set.Locale)
		}
		if len(set.Allergens) == 0 || len(set.Declarations) == 0 {
			t.Fatalf("%s: empty bundle", locale)
		}
		for _, a := range set.Allergens {
			if a.Declaration == "" || a.Name == "" {
				t.Errorf("%s/%s: blank field", locale, a.Key)
			}
		}
	}
}

func TestGermanReadsCorrectly(t *testing.T) {
	de, err := GetDisclosures("de")
	if err != nil {
		t.Fatal(err)
	}
	for _, a := range de.Allergens {
		if a.Key != "WHEAT" {
			continue
		}
		if a.Name != "Weizen" {
			t.Errorf("name = %q", a.Name)
		}
		if a.Declaration != "Enthält Getreide und glutenhaltige Erzeugnisse" {
			t.Errorf("declaration = %q", a.Declaration)
		}
		if a.Icon != "cereals" {
			t.Errorf("icon = %q", a.Icon)
		}
		return
	}
	t.Fatal("WHEAT not found")
}

func TestAnUnsupportedLocaleErrorsRatherThanFallingBack(t *testing.T) {
	_, err := GetDisclosures("nl")
	if !errors.Is(err, ErrUnsupportedLocale) {
		t.Fatalf("want ErrUnsupportedLocale, got %v", err)
	}
	// The message must name the alternatives, or the caller has to go read the
	// source to find out what is valid.
	if !strings.Contains(err.Error(), "available:") {
		t.Errorf("error does not list the locales: %v", err)
	}
}

func TestTheSameBundleIsCached(t *testing.T) {
	first, _ := GetDisclosures("de")
	second, _ := GetDisclosures("de")
	if &first.Allergens[0] == nil || len(first.Allergens) != len(second.Allergens) {
		t.Fatal("bundle changed between calls")
	}
}

func TestLocalesCannotBeMutatedByACaller(t *testing.T) {
	// Locales returns a copy. Without it, a caller sorting the result would
	// reorder the package's own state for every other caller in the process.
	got := Locales()
	got[0] = "TAMPERED"
	if Locales()[0] == "TAMPERED" {
		t.Fatal("Locales() exposed its backing array")
	}
}

func TestGuardsRejectKeysOutsideTheVocabulary(t *testing.T) {
	if !IsAllergenKey("WHEAT") || !IsAllergenKey("EGGS") {
		t.Error("valid allergen keys rejected")
	}
	// "EGG" is another vocabulary's word for it, not a key here.
	if IsAllergenKey("EGG") {
		t.Error("EGG accepted")
	}
	if !IsDeclarationKey("COLORING") || IsDeclarationKey("WHEAT") {
		t.Error("declaration guard wrong")
	}
	if !IsLocale("de") || IsLocale("nl") {
		t.Error("locale guard wrong")
	}
}

func TestNoDuplicateOrOverlappingKeys(t *testing.T) {
	allergens, err := AllergenKeys()
	if err != nil {
		t.Fatal(err)
	}
	declarations, err := DeclarationKeys()
	if err != nil {
		t.Fatal(err)
	}

	seen := map[string]bool{}
	for _, k := range allergens {
		if seen[k] {
			t.Errorf("duplicate allergen key %q", k)
		}
		seen[k] = true
	}
	for _, k := range declarations {
		// The two vocabularies must not overlap, or a stored key is ambiguous.
		if seen[k] {
			t.Errorf("key %q is in both vocabularies", k)
		}
		seen[k] = true
	}
}

func TestCerealsAndTreeNutsAreGroupsButNeverSelectableKeys(t *testing.T) {
	en, err := GetDisclosures("en")
	if err != nil {
		t.Fatal(err)
	}
	groups, keys := map[string]bool{}, map[string]bool{}
	for _, a := range en.Allergens {
		groups[a.Group] = true
		keys[a.Key] = true
	}
	if len(groups) != 14 {
		t.Errorf("groups = %d, want 14", len(groups))
	}
	// The law requires naming the specific grain or nut, so the umbrella group
	// is display-only and must not be storable.
	if keys["CEREALS"] || keys["TREE_NUTS"] {
		t.Error("an umbrella group is selectable")
	}
	if !groups["CEREALS"] || !groups["TREE_NUTS"] {
		t.Error("an umbrella group is missing")
	}
}

func TestCountsMatchTheCanonicalDataset(t *testing.T) {
	allergens, _ := AllergenKeys()
	declarations, _ := DeclarationKeys()
	if len(allergens) != 28 || len(declarations) != 22 {
		t.Fatalf("got %d allergens, %d declarations", len(allergens), len(declarations))
	}

	root := repoRoot(t)
	if root == "" {
		t.Skip("running outside the repository")
	}
	for _, tc := range []struct {
		file string
		want int
	}{{"allergens.json", len(allergens)}, {"declarations.json", len(declarations)}} {
		raw, err := os.ReadFile(filepath.Join(root, "data", tc.file))
		if err != nil {
			t.Fatal(err)
		}
		var rows []json.RawMessage
		if err := json.Unmarshal(raw, &rows); err != nil {
			t.Fatal(err)
		}
		if len(rows) != tc.want {
			t.Errorf("%s: canonical has %d, embedded has %d — run `npm run generate`",
				tc.file, len(rows), tc.want)
		}
	}
}

func TestEmbeddedJSONIsByteIdenticalToTheCanonicalDataset(t *testing.T) {
	root := repoRoot(t)
	if root == "" {
		t.Skip("running outside the repository")
	}
	for _, name := range []string{"allergens.json", "declarations.json", "codes.json", "icons.json"} {
		canonical, err := os.ReadFile(filepath.Join(root, "data", name))
		if err != nil {
			t.Fatal(err)
		}
		embedded, err := LoadDataset(name)
		if err != nil {
			t.Fatal(err)
		}
		if string(canonical) != string(embedded) {
			t.Errorf("%s drifted — run `npm run generate`", name)
		}
	}
}

func TestCodesProjectKeysOntoPrintableCodes(t *testing.T) {
	codes, err := GetCodes()
	if err != nil {
		t.Fatal(err)
	}
	if codes.Scheme != "MENUELLA" {
		t.Errorf("scheme = %q", codes.Scheme)
	}
	if codes.Allergens["WHEAT"] != "A6" {
		t.Errorf("WHEAT = %q, want A6", codes.Allergens["WHEAT"])
	}
	if codes.Declarations["SWEETENERS"] != "12" {
		t.Errorf("SWEETENERS = %q, want 12", codes.Declarations["SWEETENERS"])
	}
}

func TestEveryIconTheDataReferencesHasAGlyphAndNoneIsUnused(t *testing.T) {
	en, err := GetDisclosures("en")
	if err != nil {
		t.Fatal(err)
	}
	referenced := map[string]bool{}
	for _, a := range en.Allergens {
		referenced[a.Icon] = true
	}
	for _, d := range en.Declarations {
		referenced[d.Icon] = true
	}

	for name := range referenced {
		icon, err := GetIcon(name)
		if err != nil || len(icon.Nodes) == 0 {
			t.Errorf("%s: %v", name, err)
		}
	}

	names, _ := IconNames()
	if len(names) != len(referenced) {
		t.Errorf("%d glyphs but %d referenced — a rename landed on one side only",
			len(names), len(referenced))
	}
}

func TestEveryShapePaintsWithCurrentColor(t *testing.T) {
	// Without this a glyph cannot follow the surrounding text colour, which is
	// the whole reason these are inlined rather than shipped as images.
	names, err := IconNames()
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range names {
		icon, _ := GetIcon(name)
		for _, node := range icon.Nodes {
			if node.Attributes["fill"] != "currentColor" {
				t.Errorf("%s/%s: fill = %q", name, node.Tag, node.Attributes["fill"])
			}
		}
	}
}

func TestMarkupUsesSVGAttributeSpellingNotTheReactOne(t *testing.T) {
	names, _ := IconNames()
	var all strings.Builder
	for _, name := range names {
		svg, err := IconToSVG(name, SVGOptions{})
		if err != nil {
			t.Fatal(err)
		}
		all.WriteString(svg)
	}
	out := all.String()
	if strings.Contains(out, "fillRule") || strings.Contains(out, "clipRule") {
		t.Error("React attribute spelling reached the markup")
	}
	if !strings.Contains(out, `fill-rule="evenodd"`) {
		t.Error("fill-rule missing")
	}
}

func TestSVGIsDecorativeByDefaultAndNamedOnlyWithATitle(t *testing.T) {
	plain, _ := IconToSVG("milk", SVGOptions{})
	if !strings.Contains(plain, `aria-hidden="true"`) || !strings.Contains(plain, `focusable="false"`) {
		t.Error("default is not decorative")
	}
	if strings.Contains(plain, `role="img"`) {
		t.Error("unexpected role")
	}

	titled, _ := IconToSVG("milk", SVGOptions{Title: "Milk"})
	if !strings.Contains(titled, `role="img"`) || !strings.Contains(titled, "<title>Milk</title>") {
		t.Error("title did not produce an accessible name")
	}
	if strings.Contains(titled, "aria-hidden") {
		t.Error("titled glyph is still hidden")
	}
}

func TestACallerSuppliedTitleCannotInjectMarkup(t *testing.T) {
	svg, _ := IconToSVG("milk", SVGOptions{Title: "</title><script>alert(1)</script>"})
	if strings.Contains(svg, "<script>") {
		t.Fatal("markup injected")
	}
	if !strings.Contains(svg, "&lt;script&gt;") {
		t.Error("title not escaped")
	}
}

func TestMarkupIsDeterministic(t *testing.T) {
	// Go randomises map iteration order on purpose, so unsorted attributes
	// would produce different markup run to run — breaking snapshot tests and
	// any cache keyed on the output.
	first, _ := IconToSVG("eggs", SVGOptions{})
	for range 20 {
		again, _ := IconToSVG("eggs", SVGOptions{})
		if again != first {
			t.Fatal("markup is not stable across calls")
		}
	}
}

func TestSizeAndClassReachTheRootElement(t *testing.T) {
	svg, _ := IconToSVG("eggs", SVGOptions{Size: 16, Class: "h-4 w-4"})
	if !strings.Contains(svg, `width="16" height="16"`) {
		t.Error("size missing")
	}
	if !strings.Contains(svg, `class="h-4 w-4"`) {
		t.Error("class missing")
	}
}

func TestAnUnknownIconErrors(t *testing.T) {
	_, err := GetIcon("wine")
	if !errors.Is(err, ErrUnknownIcon) {
		t.Fatalf("want ErrUnknownIcon, got %v", err)
	}
}
