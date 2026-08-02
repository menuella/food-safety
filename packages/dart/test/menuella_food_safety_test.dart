import 'dart:convert';
import 'dart:io';

import 'package:menuella_food_safety/menuella_food_safety.dart';
import 'package:test/test.dart';

/// The repo root, found by walking up until the source JSON is visible.
///
/// Tests read it directly on purpose: this binding ships GENERATED Dart, so if
/// the generator ever stopped being run the package would carry stale data and
/// every other test here would still pass. Comparing against the source is the
/// only assertion that catches that — and it is the one risk a generated
/// binding has that a hand-written one does not.
Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/data/allergens.json').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate the repo root.');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('disclosures', () {
    test('every locale resolves to a complete bundle', () {
      for (final locale in locales) {
        final set = getDisclosures(locale);
        expect(set.locale, locale);
        expect(set.allergens, isNotEmpty);
        expect(set.declarations, isNotEmpty);
        for (final a in set.allergens) {
          expect(a.declaration, isNotEmpty, reason: '$locale/${a.key}');
          expect(a.name, isNotEmpty, reason: '$locale/${a.key}');
        }
      }
    });

    test('an unknown locale throws rather than falling back', () {
      expect(
        () => getDisclosures('nope'),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('Available:'))),
      );
    });

    test('guards reject keys outside the vocabulary', () {
      expect(isAllergenKey('WHEAT'), isTrue);
      expect(isAllergenKey('EGGS'), isTrue);
      // 'EGG' is another vocabulary's word for it, not a key here.
      expect(isAllergenKey('EGG'), isFalse);
      expect(isDeclarationKey('COLORING'), isTrue);
      expect(isDeclarationKey('WHEAT'), isFalse);
      expect(isAllergenKey(null), isFalse);
    });

    test('counts match the source JSON on disk', () {
      final root = _repoRoot();
      final allergens = jsonDecode(
          File('${root.path}/data/allergens.json').readAsStringSync()) as List;
      final declarations = jsonDecode(
              File('${root.path}/data/declarations.json').readAsStringSync())
          as List;

      expect(allergenKeys.length, allergens.length);
      expect(declarationKeys.length, declarations.length);
      expect(allergenKeys.length, 28);
      expect(declarationKeys.length, 22);
      expect(codeScheme, 'MENUELLA');
    });

    test('CEREALS and TREE_NUTS are groups but never selectable keys', () {
      final en = getDisclosures('en');
      final groups = en.allergens.map((a) => a.group).toSet();
      final keys = en.allergens.map((a) => a.key).toSet();

      expect(groups.length, 14);
      // The law requires naming the specific grain or nut, so the umbrella
      // group is display-only and must not be storable.
      expect(keys.contains('CEREALS'), isFalse);
      expect(keys.contains('TREE_NUTS'), isFalse);
      expect(groups.contains('CEREALS'), isTrue);
      expect(groups.contains('TREE_NUTS'), isTrue);
    });
  });

  group('icons', () {
    test('every icon the data references has a glyph, and no glyph is unused',
        () {
      final en = getDisclosures('en');
      final referenced = <String>{
        ...en.allergens.map((a) => a.icon),
        ...en.declarations.map((d) => d.icon),
      };
      for (final name in referenced) {
        expect(getIcon(name).nodes, isNotEmpty, reason: name);
      }
      expect(referenced.toList()..sort(), iconNames.toList()..sort());
    });

    test('every shape paints with currentColor', () {
      // Without this a glyph cannot follow the surrounding text colour, which
      // is the whole reason these are inlined rather than served as images.
      for (final name in iconNames) {
        for (final node in getIcon(name).nodes) {
          expect(node.attributes['fill'], 'currentColor',
              reason: '$name/${node.tag}');
        }
      }
    });

    test('shape counts match the source JSON on disk', () {
      final root = _repoRoot();
      final raw =
          jsonDecode(File('${root.path}/data/icons.json').readAsStringSync())
              as Map<String, dynamic>;

      expect(raw.length, iconNames.length);
      raw.forEach((name, value) {
        final nodes = (value as Map<String, dynamic>)['nodes'] as List;
        expect(getIcon(name).nodes.length, nodes.length, reason: name);
      });
    });

    test('attributes use SVG spelling, not the React one', () {
      // The source JSON carries fillRule because its first consumer is React.
      // Emitted into markup those are attributes no renderer reads — and the
      // shape still draws, just without the even-odd rule, so the bug is a
      // subtly wrong glyph rather than a missing one.
      final all = iconNames.map(iconToSvg).join();
      expect(all, isNot(contains('fillRule')));
      expect(all, isNot(contains('clipRule')));
      expect(all, contains('fill-rule="evenodd"'));
    });

    test('svg is decorative by default and named only with a title', () {
      final plain = iconToSvg('milk');
      expect(plain, contains('aria-hidden="true"'));
      expect(plain, contains('focusable="false"'));
      expect(plain, isNot(contains('role="img"')));

      final titled = iconToSvg('milk', title: 'Milk');
      expect(titled, contains('role="img"'));
      expect(titled, contains('<title>Milk</title>'));
      expect(titled, isNot(contains('aria-hidden')));
    });

    test('a caller-supplied title cannot inject markup', () {
      final svg = iconToSvg('milk', title: '</title><script>alert(1)</script>');
      expect(svg, isNot(contains('<script>')));
      expect(svg, contains('&lt;script&gt;'));
    });

    test('size and class reach the root element', () {
      final svg = iconToSvg('eggs', size: 16, cssClass: 'h-4 w-4');
      expect(svg, contains('width="16" height="16"'));
      expect(svg, contains('class="h-4 w-4"'));
    });

    test('an unknown icon throws and names what is available', () {
      expect(
        () => getIcon('wine'),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('Available:'))),
      );
    });
  });
}
