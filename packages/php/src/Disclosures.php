<?php

declare(strict_types=1);

namespace Menuella\FoodSafety;

/** Every disclosure for one locale, ready to render. */
final readonly class Disclosures
{
    /**
     * @param list<Allergen>    $allergens
     * @param list<Declaration> $declarations
     */
    public function __construct(
        public string $locale,
        /** The locale this bundle falls back to for anything it does not carry. */
        public string $fallbackLocale,
        public array $allergens,
        public array $declarations,
    ) {
    }
}
