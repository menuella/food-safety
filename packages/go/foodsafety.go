// Package foodsafety is the Menuella food-safety vocabulary: EU Reg. 1169/2011
// Annex II allergens and the Menuella declarations, in six languages.
//
// Semantic keys instead of country-specific numbers — store the key, render the
// code, never the reverse.
//
//	de, err := foodsafety.GetDisclosures("de")
//	// allergen "WHEAT" → "Enthält Getreide und glutenhaltige Erzeugnisse"
//
// This package does not do i18n. Hand it the locale your application already
// resolved; it will not sniff the environment, negotiate, or quietly fall back.
//
// The dataset is embedded at compile time, so the binary is self-contained and
// there is nothing to find on disk at runtime. encoding/json is in the standard
// library, so the module has no dependencies.
package foodsafety

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"sort"
	"strings"
	"sync"
)

//go:embed data
var dataFS embed.FS

// Sentinel errors, so callers can branch with errors.Is rather than matching on
// message text.
var (
	// ErrUnsupportedLocale means the locale has no bundle. Locales lists those
	// that do.
	ErrUnsupportedLocale = errors.New("foodsafety: unsupported locale")

	// ErrUnknownIcon means the name has no glyph.
	ErrUnknownIcon = errors.New("foodsafety: unknown icon")
)

// Allergen is one allergen, resolved for a locale.
type Allergen struct {
	// Key is the stored identifier, e.g. "WHEAT". This is what a product row
	// holds.
	Key string `json:"key"`

	// Group is its LMIV group, e.g. "CEREALS". Twelve groups are also
	// selectable keys; CEREALS and TREE_NUTS are display-only, because the law
	// requires naming the specific grain or nut.
	Group string `json:"group"`

	// IsMember is true when this key is one member of a multi-member group.
	IsMember bool `json:"isMember"`

	// Icon is the glyph name, e.g. "cereals".
	Icon string `json:"icon"`

	// Name is the short label, e.g. "Wheat".
	Name string `json:"name"`

	// Declaration is the sentence with legal force. This is what must reach
	// the guest.
	Declaration string `json:"declaration"`

	// Description is a longer explanation, for tooltips and help text.
	Description string `json:"description"`
}

// Declaration is one additive, beverage or product note, resolved for a locale.
type Declaration struct {
	Key string `json:"key"`

	// Category is one of ADDITIVE, BEVERAGE, WARNING, PRODUCT.
	Category string `json:"category"`

	// Icon is the glyph name. All declarations share one generic glyph.
	Icon string `json:"icon"`

	Name        string `json:"name"`
	Description string `json:"description"`
}

// Disclosures is every disclosure for one locale, ready to render.
type Disclosures struct {
	Locale string `json:"locale"`

	// FallbackLocale is the locale this bundle falls back to for anything it
	// does not itself carry.
	FallbackLocale string `json:"fallbackLocale"`

	Allergens    []Allergen    `json:"allergens"`
	Declarations []Declaration `json:"declarations"`
}

// Codes is the footnote-code scheme: letters for allergens, numbers for
// declarations.
type Codes struct {
	Scheme     string `json:"scheme"`
	Convention string `json:"convention"`

	// Allergens maps an allergen key to its printable code, e.g. WHEAT → A6.
	Allergens map[string]string `json:"allergens"`

	// Declarations maps a declaration key to its code, e.g. SWEETENERS → 12.
	Declarations map[string]string `json:"declarations"`
}

// IconNode is a single shape in a glyph.
type IconNode struct {
	// Tag is "path" or "circle".
	Tag string

	// Attributes are named in SVG spelling (fill-rule, not fillRule).
	Attributes map[string]string
}

// Icon is a glyph as data, for callers that build shapes rather than markup.
type Icon struct {
	// ViewBox is always "0 0 24 24".
	ViewBox string
	Nodes   []IconNode
}

// Locales returns the locales with a prebuilt bundle.
//
// A fresh slice each call, so a caller cannot reorder the package's own state.
func Locales() []string {
	return append([]string(nil), locales...)
}

var locales = []string{"de", "en", "es", "fr", "it", "tr"}

// FallbackLocale is the locale a bundle falls back to for anything it does not
// itself carry.
const FallbackLocale = "en"

// Decoded values are cached: re-parsing per call would allocate the whole
// dataset again on what is often a per-request path.
var (
	bundleCache sync.Map // locale → *Disclosures
	iconsOnce   sync.Once
	iconsValue  map[string]Icon
	iconsErr    error
	codesOnce   sync.Once
	codesValue  Codes
	codesErr    error
	keysOnce    sync.Once
	allergenKey []string
	declKey     []string
	keysErr     error
)

// IsLocale reports whether value is a locale with a bundle.
func IsLocale(value string) bool {
	for _, l := range locales {
		if l == value {
			return true
		}
	}
	return false
}

// GetDisclosures returns every disclosure for locale, ready to render.
//
// It returns an error wrapping ErrUnsupportedLocale rather than falling back: a
// silently wrong language on an allergen panel is worse than a loud failure.
// The caller knows which locales it supports, and IsLocale is there to ask.
func GetDisclosures(locale string) (Disclosures, error) {
	if !IsLocale(locale) {
		return Disclosures{}, fmt.Errorf(
			"%w: %q (available: %s)", ErrUnsupportedLocale, locale, strings.Join(locales, ", "))
	}

	if cached, ok := bundleCache.Load(locale); ok {
		return *cached.(*Disclosures), nil
	}

	var d Disclosures
	if err := readJSON("data/bundles/"+locale+".json", &d); err != nil {
		return Disclosures{}, err
	}

	bundleCache.Store(locale, &d)
	return d, nil
}

// GetCodes returns the footnote-code scheme.
func GetCodes() (Codes, error) {
	codesOnce.Do(func() { codesErr = readJSON("data/codes.json", &codesValue) })
	return codesValue, codesErr
}

// CodeScheme returns the scheme these codes belong to.
func CodeScheme() (string, error) {
	c, err := GetCodes()
	return c.Scheme, err
}

// AllergenKeys returns every selectable allergen key, in canonical order.
//
// Keys are locale-independent, so this reads the structural file rather than
// taking a locale.
func AllergenKeys() ([]string, error) {
	if err := loadKeys(); err != nil {
		return nil, err
	}
	return append([]string(nil), allergenKey...), nil
}

// DeclarationKeys returns every declaration key, in canonical order.
func DeclarationKeys() ([]string, error) {
	if err := loadKeys(); err != nil {
		return nil, err
	}
	return append([]string(nil), declKey...), nil
}

// IsAllergenKey reports whether value is a current allergen key. Retired keys
// return false.
func IsAllergenKey(value string) bool {
	if loadKeys() != nil {
		return false
	}
	return contains(allergenKey, value)
}

// IsDeclarationKey reports whether value is a current declaration key.
func IsDeclarationKey(value string) bool {
	if loadKeys() != nil {
		return false
	}
	return contains(declKey, value)
}

// IconNames returns every icon name that has a glyph.
func IconNames() ([]string, error) {
	all, err := allIcons()
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(all))
	for name := range all {
		names = append(names, name)
	}
	sort.Strings(names)
	return names, nil
}

// GetIcon returns the glyph named name, as data.
//
// Every shape paints with currentColor, so a glyph inherits the surrounding
// text colour and follows a light or dark theme with no second asset.
//
// It returns an error wrapping ErrUnknownIcon if the name has no glyph.
func GetIcon(name string) (Icon, error) {
	all, err := allIcons()
	if err != nil {
		return Icon{}, err
	}
	icon, ok := all[name]
	if !ok {
		return Icon{}, fmt.Errorf("%w: %q", ErrUnknownIcon, name)
	}
	return icon, nil
}

// SVGOptions tunes IconToSVG.
type SVGOptions struct {
	// Size is the rendered width and height in px. Zero means 24.
	Size int

	// Class is added to the root element.
	Class string

	// Title gives the glyph an accessible name and role="img".
	//
	// Leave it empty when the declaration text sits beside the icon: then the
	// glyph is decoration, stays aria-hidden, and the text carries the meaning.
	// That is the correct default on a legal surface.
	Title string
}

// IconToSVG returns the glyph as an <svg> string, for anything that
// interpolates markup — templates, e-mail, PDF.
//
// It returns an error wrapping ErrUnknownIcon if the name has no glyph.
func IconToSVG(name string, opts SVGOptions) (string, error) {
	icon, err := GetIcon(name)
	if err != nil {
		return "", err
	}

	size := opts.Size
	if size == 0 {
		size = 24
	}

	var b strings.Builder
	b.WriteString(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="`)
	b.WriteString(html.EscapeString(icon.ViewBox))
	fmt.Fprintf(&b, `" width="%d" height="%d" fill="none"`, size, size)

	if opts.Class != "" {
		b.WriteString(` class="` + html.EscapeString(opts.Class) + `"`)
	}

	if opts.Title != "" {
		b.WriteString(` role="img"><title>` + html.EscapeString(opts.Title) + `</title>`)
	} else {
		b.WriteString(` aria-hidden="true" focusable="false">`)
	}

	for _, node := range icon.Nodes {
		b.WriteString("<" + node.Tag)
		// Sorted: Go randomises map iteration order on purpose, so unsorted
		// output would differ between runs — breaking snapshot tests and any
		// cache keyed on the markup.
		keys := make([]string, 0, len(node.Attributes))
		for k := range node.Attributes {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			b.WriteString(" " + k + `="` + html.EscapeString(node.Attributes[k]) + `"`)
		}
		b.WriteString("/>")
	}

	b.WriteString("</svg>")
	return b.String(), nil
}

// LoadDataset returns the raw JSON for one of the packaged files, for tooling
// that wants the dataset rather than resolved values.
//
// Valid names are "allergens.json", "declarations.json", "codes.json" and
// "icons.json".
func LoadDataset(name string) ([]byte, error) {
	return dataFS.ReadFile("data/" + name)
}

// The JSON carries React attribute spelling, because its first consumer is
// React. Markup needs the SVG one — and an unmapped name still draws, just
// without the even-odd rule, so the bug would be a subtly wrong glyph rather
// than a missing one.
var svgAttribute = map[string]string{"fillRule": "fill-rule", "clipRule": "clip-rule"}

func allIcons() (map[string]Icon, error) {
	iconsOnce.Do(func() {
		// Decoded through json.RawMessage rather than straight into a struct:
		// a node is ["path", { … }], a heterogeneous array whose first element
		// is a string and second an object.
		var raw map[string]struct {
			ViewBox string              `json:"viewBox"`
			Nodes   [][]json.RawMessage `json:"nodes"`
		}
		if iconsErr = readJSON("data/icons.json", &raw); iconsErr != nil {
			return
		}

		iconsValue = make(map[string]Icon, len(raw))
		for name, r := range raw {
			nodes := make([]IconNode, 0, len(r.Nodes))
			for _, pair := range r.Nodes {
				if len(pair) != 2 {
					iconsErr = fmt.Errorf("foodsafety: malformed node in icon %q", name)
					return
				}
				var tag string
				if iconsErr = json.Unmarshal(pair[0], &tag); iconsErr != nil {
					return
				}
				var attrs map[string]string
				if iconsErr = json.Unmarshal(pair[1], &attrs); iconsErr != nil {
					return
				}
				mapped := make(map[string]string, len(attrs))
				for k, v := range attrs {
					if svg, ok := svgAttribute[k]; ok {
						k = svg
					}
					mapped[k] = v
				}
				nodes = append(nodes, IconNode{Tag: tag, Attributes: mapped})
			}
			iconsValue[name] = Icon{ViewBox: r.ViewBox, Nodes: nodes}
		}
	})
	return iconsValue, iconsErr
}

func loadKeys() error {
	keysOnce.Do(func() {
		var allergens []struct {
			Key string `json:"key"`
		}
		if keysErr = readJSON("data/allergens.json", &allergens); keysErr != nil {
			return
		}
		var declarations []struct {
			Key string `json:"key"`
		}
		if keysErr = readJSON("data/declarations.json", &declarations); keysErr != nil {
			return
		}
		for _, a := range allergens {
			allergenKey = append(allergenKey, a.Key)
		}
		for _, d := range declarations {
			declKey = append(declKey, d.Key)
		}
	})
	return keysErr
}

func readJSON(path string, into any) error {
	raw, err := dataFS.ReadFile(path)
	if err != nil {
		return fmt.Errorf("foodsafety: embedded dataset is missing %s: %w", path, err)
	}
	if err := json.Unmarshal(raw, into); err != nil {
		return fmt.Errorf("foodsafety: could not decode %s: %w", path, err)
	}
	return nil
}

func contains(haystack []string, needle string) bool {
	for _, v := range haystack {
		if v == needle {
			return true
		}
	}
	return false
}
