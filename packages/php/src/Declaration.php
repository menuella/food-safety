<?php

declare(strict_types=1);

namespace Menuella\FoodSafety;

/** One declaration — an additive, beverage or product note — for a locale. */
final readonly class Declaration
{
    public function __construct(
        /** The stored identifier, e.g. COLORING. */
        public string $key,
        /** One of ADDITIVE, BEVERAGE, WARNING, PRODUCT. */
        public string $category,
        /** The glyph name. All declarations share one generic glyph. */
        public string $icon,
        /** Short label, e.g. "With Coloring Agent". */
        public string $name,
        /** A longer explanation. */
        public string $description,
    ) {
    }
}
