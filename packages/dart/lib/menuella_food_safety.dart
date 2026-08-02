/// The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens
/// and the Menuella declarations, in six languages.
///
/// Semantic keys rather than country-specific numbers — store the key, render
/// the code, never the reverse.
///
/// This library does **not** do i18n. Hand it the locale your app already
/// resolved; it will not sniff the platform, negotiate, or quietly fall back.
///
/// ```dart
/// final de = getDisclosures('de');
/// de.allergens.firstWhere((a) => a.key == 'WHEAT').declaration;
/// // 'Enthält Getreide und glutenhaltige Erzeugnisse'
/// ```
library;

import 'src/data.g.dart';
import 'src/icons.g.dart';
import 'src/models.dart';

export 'src/models.dart'
    show Allergen, Declaration, DisclosureSet, Icon, IconNode;

/// Locales with a prebuilt bundle.
const List<String> locales = kLocales;

/// The locale a bundle falls back to for anything it does not itself carry.
const String fallbackLocale = kFallbackLocale;

/// Every selectable allergen key.
const List<String> allergenKeys = kAllergenKeys;

/// Every declaration key.
const List<String> declarationKeys = kDeclarationKeys;

/// Every icon name that has a glyph.
const List<String> iconNames = kIconNames;

/// The footnote-code scheme these codes belong to.
const String codeScheme = kCodeScheme;

/// True when [value] is a locale with a bundle.
bool isLocale(String? value) => value != null && kBundles.containsKey(value);

/// True when [value] is a current allergen key. Retired keys return false.
bool isAllergenKey(String? value) =>
    value != null && _allergenSet.contains(value);

/// True when [value] is a current declaration key.
bool isDeclarationKey(String? value) =>
    value != null && _declarationSet.contains(value);

final Set<String> _allergenSet = Set<String>.unmodifiable(kAllergenKeys);
final Set<String> _declarationSet = Set<String>.unmodifiable(kDeclarationKeys);

/// Every disclosure for [locale], ready to render.
///
/// Throws [ArgumentError] if the locale has no bundle. It throws rather than
/// falling back because a silently wrong language on an allergen panel is worse
/// than a loud failure — the caller knows which locales it supports, and
/// [isLocale] is there to ask.
DisclosureSet getDisclosures(String locale) {
  final bundle = kBundles[locale];
  if (bundle == null) {
    throw ArgumentError.value(
      locale,
      'locale',
      'No disclosures for this locale. Available: ${kLocales.join(', ')}',
    );
  }
  return bundle;
}

/// The glyph named [name], as data.
///
/// Every shape paints with `currentColor`, so a glyph inherits the surrounding
/// text colour and follows a light/dark theme with no second asset.
///
/// These glyphs carry legal meaning. Render one **alongside** its declaration
/// text, never instead of it, and keep it excluded from the semantics tree —
/// the text is the accessible content.
///
/// Throws [ArgumentError] if the name has no glyph.
Icon getIcon(String name) {
  final icon = kIcons[name];
  if (icon == null) {
    throw ArgumentError.value(
      name,
      'name',
      'No icon with this name. Available: ${kIconNames.join(', ')}',
    );
  }
  return icon;
}

/// The glyph named [name] as an `<svg>` string, for templates that interpolate
/// markup — server-rendered HTML, e-mail, PDF.
///
/// Decorative by default: emits `aria-hidden` unless [title] is given, which
/// switches it to `role="img"` with a `<title>`. That is the correct default on
/// a legal surface, where the declaration text carries the meaning.
///
/// Throws [ArgumentError] if the name has no glyph.
String iconToSvg(
  String name, {
  int size = 24,
  String? cssClass,
  String? title,
}) {
  final icon = getIcon(name);
  final buffer = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="')
    ..write(_escape(icon.viewBox))
    ..write('" width="$size" height="$size" fill="none"');

  if (cssClass != null && cssClass.isNotEmpty) {
    buffer.write(' class="${_escape(cssClass)}"');
  }

  if (title == null || title.isEmpty) {
    buffer.write(' aria-hidden="true" focusable="false">');
  } else {
    buffer.write(' role="img"><title>${_escape(title)}</title>');
  }

  for (final node in icon.nodes) {
    buffer.write('<${node.tag}');
    node.attributes.forEach((key, value) {
      buffer.write(' $key="${_escape(value)}"');
    });
    buffer.write('/>');
  }

  return (buffer..write('</svg>')).toString();
}

/// The path data is ours, but [iconToSvg]'s `title` is caller-supplied and
/// lands in markup.
String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
