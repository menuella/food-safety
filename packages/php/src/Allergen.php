<?php

declare(strict_types=1);

namespace Menuella\FoodSafety;

/**
 * One allergen, resolved for a locale.
 *
 * Readonly because the dataset is a process-wide singleton: a caller that
 * mutated an entry would corrupt it for every other caller in the request.
 */
final readonly class Allergen
{
    public function __construct(
        /** The stored identifier, e.g. WHEAT. This is what a product row holds. */
        public string $key,
        /**
         * Its LMIV group, e.g. CEREALS. Twelve groups are also selectable keys;
         * CEREALS and TREE_NUTS are display-only, because the law requires
         * naming the specific grain or nut.
         */
        public string $group,
        /** True when this key is one member of a multi-member group. */
        public bool $isMember,
        /** The glyph name, e.g. cereals. */
        public string $icon,
        /** Short label, e.g. "Wheat". */
        public string $name,
        /** The sentence with legal force. This is what must reach the guest. */
        public string $declaration,
        /** A longer explanation, for tooltips and help text. */
        public string $description,
    ) {
    }
}
