import 'package:menuella_food_safety/menuella_food_safety.dart';

void main() {
  // Hand it the locale your app already resolved — this library does no i18n
  // of its own.
  final de = getDisclosures('de');

  final wheat = de.allergens.firstWhere((a) => a.key == 'WHEAT');
  print(wheat.name); // Weizen
  print(wheat.declaration); // Enthält Getreide und glutenhaltige Erzeugnisse

  // Collapse to one row per LMIV group: the group carries the declaration with
  // legal force, and the specific grain or nut is named beneath it.
  final selected = <String>{'WHEAT', 'MILK', 'SESAME'};
  final byGroup = <String, List<Allergen>>{};
  for (final a in de.allergens.where((a) => selected.contains(a.key))) {
    byGroup.putIfAbsent(a.group, () => <Allergen>[]).add(a);
  }

  byGroup.forEach((group, members) {
    print('${members.first.declaration}'
        '${members.any((m) => m.isMember) ? ' — '
            '${members.where((m) => m.isMember).map((m) => m.name).join(', ')}' : ''}');
  });

  // Glyphs paint with currentColor, so they follow the surrounding text colour
  // and a light/dark theme with no second asset. Decorative by default: the
  // declaration text beside them is what carries the meaning.
  print(iconToSvg(wheat.icon, size: 16));

  // Guards, for validating what a user or an API sent you.
  print(isAllergenKey('WHEAT')); // true
  print(isAllergenKey('EGG')); // false — the key is EGGS
}
