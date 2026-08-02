<?php

declare(strict_types=1);

namespace Menuella\FoodSafety;

/** A single shape in a glyph. */
final readonly class IconNode
{
    /**
     * @param 'path'|'circle'       $tag
     * @param array<string, string> $attributes attribute names in SVG spelling
     *                                          (fill-rule, not fillRule)
     */
    public function __construct(
        public string $tag,
        public array $attributes,
    ) {
    }
}
