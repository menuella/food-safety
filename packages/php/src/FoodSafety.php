<?php

declare(strict_types=1);

namespace Menuella\FoodSafety;

use InvalidArgumentException;
use RuntimeException;

/**
 * The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens and
 * the Menuella declarations, in six languages.
 *
 * Semantic keys instead of country-specific numbers — store the key, render the
 * code, never the reverse.
 *
 *     $de = FoodSafety::getDisclosures('de');
 *     // 'Enthält Getreide und glutenhaltige Erzeugnisse'
 *
 * This class does **not** do i18n. Hand it the locale your app already
 * resolved; it will not sniff, negotiate, or quietly fall back.
 *
 * The data is the same JSON every other binding ships, read with json_decode —
 * which is in core, so the package has no dependencies.
 */
final class FoodSafety
{
    /** Locales with a prebuilt bundle. */
    public const LOCALES = ['de', 'en', 'es', 'fr', 'it', 'tr'];

    /** The locale a bundle falls back to for anything it does not itself carry. */
    public const FALLBACK_LOCALE = 'en';

    /** @var array<string, Disclosures> */
    private static array $bundles = [];

    /** @var array<string, Icon>|null */
    private static ?array $icons = null;

    /** @var array<string, mixed>|null */
    private static ?array $files = null;

    /**
     * The JSON carries React attribute spelling, because its first consumer is
     * React. Markup needs the SVG one — and an unmapped name still draws, just
     * without the even-odd rule, so the bug would be a subtly wrong glyph
     * rather than a missing one.
     */
    private const SVG_ATTRIBUTE = ['fillRule' => 'fill-rule', 'clipRule' => 'clip-rule'];

    /** True when the value is a locale with a bundle. */
    public static function isLocale(mixed $value): bool
    {
        return is_string($value) && in_array($value, self::LOCALES, true);
    }

    /** True when the value is a current allergen key. Retired keys return false. */
    public static function isAllergenKey(mixed $value): bool
    {
        return is_string($value) && in_array($value, self::allergenKeys(), true);
    }

    /** True when the value is a current declaration key. */
    public static function isDeclarationKey(mixed $value): bool
    {
        return is_string($value) && in_array($value, self::declarationKeys(), true);
    }

    /**
     * Every selectable allergen key, in canonical order. Derived from the data,
     * never hand-listed.
     *
     * @return list<string>
     */
    public static function allergenKeys(): array
    {
        /** @var list<array{key: string}> $rows */
        $rows = self::read('allergens.json');

        return array_map(static fn (array $a): string => $a['key'], $rows);
    }

    /**
     * Every declaration key, in canonical order.
     *
     * @return list<string>
     */
    public static function declarationKeys(): array
    {
        /** @var list<array{key: string}> $rows */
        $rows = self::read('declarations.json');

        return array_map(static fn (array $d): string => $d['key'], $rows);
    }

    /**
     * Every icon name that has a glyph.
     *
     * @return list<string>
     */
    public static function iconNames(): array
    {
        $names = array_keys(self::icons());
        sort($names);

        return $names;
    }

    /** The footnote-code scheme these codes belong to. */
    public static function codeScheme(): string
    {
        /** @var array{scheme: string} $codes */
        $codes = self::read('codes.json');

        return $codes['scheme'];
    }

    /**
     * Every disclosure for a locale, ready to render.
     *
     * Throws rather than falling back: a silently wrong language on an allergen
     * panel is worse than a loud failure. The caller knows which locales it
     * supports, and isLocale() is there to ask.
     *
     * @throws InvalidArgumentException if the locale has no bundle
     */
    public static function getDisclosures(string $locale): Disclosures
    {
        if (isset(self::$bundles[$locale])) {
            return self::$bundles[$locale];
        }

        if (!self::isLocale($locale)) {
            throw new InvalidArgumentException(sprintf(
                'No disclosures for locale "%s". Available: %s.',
                $locale,
                implode(', ', self::LOCALES),
            ));
        }

        /** @var array{locale: string, fallbackLocale: string, allergens: list<array<string, mixed>>, declarations: list<array<string, mixed>>} $raw */
        $raw = self::read("bundles/{$locale}.json");

        return self::$bundles[$locale] = new Disclosures(
            locale: $raw['locale'],
            fallbackLocale: $raw['fallbackLocale'],
            allergens: array_map(static fn (array $a): Allergen => new Allergen(
                key: $a['key'],
                group: $a['group'],
                isMember: $a['isMember'],
                icon: $a['icon'],
                name: $a['name'],
                declaration: $a['declaration'],
                description: $a['description'],
            ), $raw['allergens']),
            declarations: array_map(static fn (array $d): Declaration => new Declaration(
                key: $d['key'],
                category: $d['category'],
                icon: $d['icon'],
                name: $d['name'],
                description: $d['description'],
            ), $raw['declarations']),
        );
    }

    /**
     * The glyph as data.
     *
     * Every shape paints with currentColor, so a glyph inherits the surrounding
     * text colour and follows a light/dark theme with no second asset.
     *
     * @throws InvalidArgumentException if the name has no glyph
     */
    public static function getIcon(string $name): Icon
    {
        return self::icons()[$name] ?? throw new InvalidArgumentException(sprintf(
            'No icon named "%s". Available: %s.',
            $name,
            implode(', ', self::iconNames()),
        ));
    }

    /**
     * The glyph as an <svg> string, for templates that interpolate markup —
     * Blade, Twig, e-mail, PDF.
     *
     * Decorative by default: emits aria-hidden unless a title is given, which
     * switches it to role="img" with a <title>. These glyphs carry legal
     * meaning, so render one alongside its declaration text, never instead of
     * it — the safe default is the free one.
     *
     * @throws InvalidArgumentException if the name has no glyph
     */
    public static function iconToSvg(
        string $name,
        int $size = 24,
        ?string $cssClass = null,
        ?string $title = null,
    ): string {
        $icon = self::getIcon($name);

        $out = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' . self::escape($icon->viewBox) . '"'
            . ' width="' . $size . '" height="' . $size . '" fill="none"';

        if ($cssClass !== null && $cssClass !== '') {
            $out .= ' class="' . self::escape($cssClass) . '"';
        }

        $out .= ($title === null || $title === '')
            ? ' aria-hidden="true" focusable="false">'
            : ' role="img"><title>' . self::escape($title) . '</title>';

        foreach ($icon->nodes as $node) {
            $out .= '<' . $node->tag;
            foreach ($node->attributes as $key => $value) {
                $out .= ' ' . $key . '="' . self::escape($value) . '"';
            }
            $out .= '/>';
        }

        return $out . '</svg>';
    }

    /**
     * The raw dataset, for tooling that wants the JSON rather than objects.
     *
     * @return array{allergens: mixed, declarations: mixed, codes: mixed, icons: mixed}
     */
    public static function loadDataset(): array
    {
        return [
            'allergens' => self::read('allergens.json'),
            'declarations' => self::read('declarations.json'),
            'codes' => self::read('codes.json'),
            'icons' => self::read('icons.json'),
        ];
    }

    /** @return array<string, Icon> */
    private static function icons(): array
    {
        if (self::$icons !== null) {
            return self::$icons;
        }

        /** @var array<string, array{viewBox: string, nodes: list<array{0: string, 1: array<string, string>}>}> $raw */
        $raw = self::read('icons.json');

        $icons = [];
        foreach ($raw as $name => $icon) {
            $nodes = [];
            foreach ($icon['nodes'] as [$tag, $attributes]) {
                $mapped = [];
                foreach ($attributes as $key => $value) {
                    $mapped[self::SVG_ATTRIBUTE[$key] ?? $key] = $value;
                }
                $nodes[] = new IconNode($tag, $mapped);
            }
            $icons[$name] = new Icon($icon['viewBox'], $nodes);
        }

        return self::$icons = $icons;
    }

    /**
     * @throws RuntimeException if the packaged dataset is missing
     */
    private static function read(string $file): mixed
    {
        if (isset(self::$files[$file])) {
            return self::$files[$file];
        }

        $path = __DIR__ . '/../data/' . $file;
        $json = @file_get_contents($path);

        if ($json === false) {
            throw new RuntimeException(sprintf(
                'Packaged dataset is missing %s. The package was installed without its data.',
                $file,
            ));
        }

        return self::$files[$file] = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    }

    /** The path data is ours, but iconToSvg's title is caller-supplied. */
    private static function escape(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}
