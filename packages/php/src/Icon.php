<?php

declare(strict_types=1);

namespace Menuella\FoodSafety;

/** A glyph as data, for callers that build elements rather than markup. */
final readonly class Icon
{
    /** @param list<IconNode> $nodes */
    public function __construct(
        /** Always "0 0 24 24". */
        public string $viewBox,
        public array $nodes,
    ) {
    }
}
