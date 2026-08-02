<?php

declare(strict_types=1);

namespace Menuella\FoodSafety\Tests;

use InvalidArgumentException;
use Menuella\FoodSafety\FoodSafety;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * Behaviour of the published surface, plus the one risk a copied dataset has.
 *
 * The repository's own validation covers the canonical JSON. What it cannot see
 * is whether the copy inside this package is the same JSON — so the tests that
 * compare against the canonical data/ are the ones that matter most here.
 * Without them, a release built without running the generator would ship stale
 * data and every other test would still pass.
 */
final class FoodSafetyTest extends TestCase
{
    private static function repoRoot(): string
    {
        $dir = __DIR__;
        while (!is_file($dir . '/data/allergens.json')) {
            $parent = dirname($dir);
            if ($parent === $dir) {
                self::fail('Could not locate the repository root.');
            }
            $dir = $parent;
        }

        return $dir;
    }

    private static function canonical(string ...$parts): mixed
    {
        $path = self::repoRoot() . '/' . implode('/', $parts);

        return json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
    }

    // ------------------------------------------------------------ dataset --

    #[Test]
    public function everyLocaleResolvesToACompleteBundle(): void
    {
        foreach (FoodSafety::LOCALES as $locale) {
            $set = FoodSafety::getDisclosures($locale);
            self::assertSame($locale, $set->locale);
            self::assertNotEmpty($set->allergens);
            self::assertNotEmpty($set->declarations);

            foreach ($set->allergens as $allergen) {
                self::assertNotSame('', $allergen->declaration, "{$locale}/{$allergen->key}");
                self::assertNotSame('', $allergen->name, "{$locale}/{$allergen->key}");
            }
        }
    }

    #[Test]
    public function anUnknownLocaleThrowsRatherThanFallingBack(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessageMatches('/Available:/');
        FoodSafety::getDisclosures('nope');
    }

    #[Test]
    public function theSameBundleIsReturnedEachTime(): void
    {
        // Cached: re-decoding per call would be a silent cost on a hot path.
        self::assertSame(FoodSafety::getDisclosures('de'), FoodSafety::getDisclosures('de'));
    }

    #[Test]
    public function entriesAreImmutable(): void
    {
        // The dataset is a process-wide singleton; a caller who mutated one
        // entry would corrupt it for everyone else in the request.
        $this->expectException(\Error::class);
        $allergen = FoodSafety::getDisclosures('en')->allergens[0];
        /** @phpstan-ignore-next-line intentionally illegal */
        $allergen->key = 'TAMPERED';
    }

    #[Test]
    public function guardsRejectKeysOutsideTheVocabulary(): void
    {
        self::assertTrue(FoodSafety::isAllergenKey('WHEAT'));
        self::assertTrue(FoodSafety::isAllergenKey('EGGS'));
        // "EGG" is another vocabulary's word for it, not a key here.
        self::assertFalse(FoodSafety::isAllergenKey('EGG'));
        self::assertTrue(FoodSafety::isDeclarationKey('COLORING'));
        self::assertFalse(FoodSafety::isDeclarationKey('WHEAT'));
        self::assertFalse(FoodSafety::isAllergenKey(null));
        self::assertFalse(FoodSafety::isLocale(42));
    }

    #[Test]
    public function noDuplicateOrOverlappingKeys(): void
    {
        $allergens = FoodSafety::allergenKeys();
        $declarations = FoodSafety::declarationKeys();

        self::assertCount(count($allergens), array_unique($allergens));
        self::assertCount(count($declarations), array_unique($declarations));
        // The two vocabularies must not overlap, or a stored key is ambiguous.
        self::assertSame([], array_intersect($allergens, $declarations));
    }

    #[Test]
    public function cerealsAndTreeNutsAreGroupsButNeverSelectableKeys(): void
    {
        $english = FoodSafety::getDisclosures('en');
        $groups = array_unique(array_map(static fn ($a) => $a->group, $english->allergens));
        $keys = array_map(static fn ($a) => $a->key, $english->allergens);

        self::assertCount(14, $groups);
        // The law requires naming the specific grain or nut, so the umbrella
        // group is display-only and must not be storable.
        self::assertNotContains('CEREALS', $keys);
        self::assertNotContains('TREE_NUTS', $keys);
        self::assertContains('CEREALS', $groups);
        self::assertContains('TREE_NUTS', $groups);
    }

    // ------------------------------- the copy matches the canonical data --

    #[Test]
    public function keyCountsMatchTheCanonicalDataset(): void
    {
        self::assertCount(count(self::canonical('data', 'allergens.json')), FoodSafety::allergenKeys());
        self::assertCount(count(self::canonical('data', 'declarations.json')), FoodSafety::declarationKeys());
        self::assertCount(28, FoodSafety::allergenKeys());
        self::assertCount(22, FoodSafety::declarationKeys());
        self::assertSame('MENUELLA', FoodSafety::codeScheme());
    }

    #[Test]
    public function packagedJsonIsByteIdenticalToTheCanonicalDataset(): void
    {
        foreach (['allergens.json', 'declarations.json', 'codes.json', 'icons.json'] as $name) {
            self::assertSame(
                file_get_contents(self::repoRoot() . '/data/' . $name),
                file_get_contents(__DIR__ . '/../data/' . $name),
                "{$name} drifted — run `npm run generate`",
            );
        }
    }

    // -------------------------------------------------------------- icons --

    #[Test]
    public function everyIconTheDataReferencesHasAGlyphAndNoneIsUnused(): void
    {
        $english = FoodSafety::getDisclosures('en');
        $referenced = array_unique(array_merge(
            array_map(static fn ($a) => $a->icon, $english->allergens),
            array_map(static fn ($d) => $d->icon, $english->declarations),
        ));

        foreach ($referenced as $name) {
            self::assertNotEmpty(FoodSafety::getIcon($name)->nodes, $name);
        }

        sort($referenced);
        self::assertSame($referenced, FoodSafety::iconNames());
    }

    #[Test]
    public function everyShapePaintsWithCurrentColor(): void
    {
        // Without this a glyph cannot follow the surrounding text colour, which
        // is the whole reason these are inlined rather than served as images.
        foreach (FoodSafety::iconNames() as $name) {
            foreach (FoodSafety::getIcon($name)->nodes as $node) {
                self::assertSame('currentColor', $node->attributes['fill'] ?? null, "{$name}/{$node->tag}");
            }
        }
    }

    #[Test]
    public function markupUsesSvgAttributeSpellingNotTheReactOne(): void
    {
        $all = implode('', array_map(FoodSafety::iconToSvg(...), FoodSafety::iconNames()));
        self::assertStringNotContainsString('fillRule', $all);
        self::assertStringNotContainsString('clipRule', $all);
        self::assertStringContainsString('fill-rule="evenodd"', $all);
    }

    #[Test]
    public function svgIsDecorativeByDefaultAndNamedOnlyWithATitle(): void
    {
        $plain = FoodSafety::iconToSvg('milk');
        self::assertStringContainsString('aria-hidden="true"', $plain);
        self::assertStringContainsString('focusable="false"', $plain);
        self::assertStringNotContainsString('role="img"', $plain);

        $titled = FoodSafety::iconToSvg('milk', title: 'Milk');
        self::assertStringContainsString('role="img"', $titled);
        self::assertStringContainsString('<title>Milk</title>', $titled);
        self::assertStringNotContainsString('aria-hidden', $titled);
    }

    #[Test]
    public function aCallerSuppliedTitleCannotInjectMarkup(): void
    {
        $svg = FoodSafety::iconToSvg('milk', title: '</title><script>alert(1)</script>');
        self::assertStringNotContainsString('<script>', $svg);
        self::assertStringContainsString('&lt;script&gt;', $svg);
    }

    #[Test]
    public function sizeAndClassReachTheRootElement(): void
    {
        $svg = FoodSafety::iconToSvg('eggs', size: 16, cssClass: 'h-4 w-4');
        self::assertStringContainsString('width="16" height="16"', $svg);
        self::assertStringContainsString('class="h-4 w-4"', $svg);
    }

    #[Test]
    public function anUnknownIconThrowsAndNamesWhatIsAvailable(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessageMatches('/Available:/');
        FoodSafety::getIcon('wine');
    }
}
