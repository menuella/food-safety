package com.menuella.foodsafety

import java.io.File
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * Behaviour of the published surface, plus the one risk generated source has:
 * drifting from the JSON it was generated from.
 *
 * The counts here are read off `data/` at the repository root rather than
 * hard-coded, because if the generator ever stopped being run this binding
 * would ship stale data and every other assertion would still pass.
 */
class FoodSafetyTest {

    private fun repoRoot(): File? {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null && !File(dir, "data/allergens.json").isFile) dir = dir.parentFile
        return dir
    }

    /** Entry count of a top-level JSON array, without pulling in a parser. */
    private fun countEntries(file: File): Int =
        Regex("\"key\"\\s*:").findAll(file.readText()).count()

    // ------------------------------------------------------------ dataset --

    @Test
    fun everyLocaleResolvesToACompleteBundle() {
        for (locale in FoodSafety.locales) {
            val set = FoodSafety.getDisclosures(locale)
            assertEquals(locale, set.locale)
            assertTrue(set.allergens.isNotEmpty())
            assertTrue(set.declarations.isNotEmpty())
            for (a in set.allergens) {
                assertTrue(a.declaration.isNotBlank(), "$locale/${a.key}")
                assertTrue(a.name.isNotBlank(), "$locale/${a.key}")
            }
        }
    }

    @Test
    fun anUnknownLocaleThrowsRatherThanFallingBack() {
        val error = assertFailsWith<IllegalArgumentException> { FoodSafety.getDisclosures("nope") }
        assertContains(error.message!!, "Available:")
    }

    @Test
    fun theSameBundleIsReturnedEachTime() {
        // Cached: rebuilding would allocate ~300 objects per call on what is
        // often a per-request path.
        assertSame(FoodSafety.getDisclosures("de"), FoodSafety.getDisclosures("de"))
    }

    @Test
    fun guardsRejectKeysOutsideTheVocabulary() {
        assertTrue(FoodSafety.isAllergenKey("WHEAT"))
        assertTrue(FoodSafety.isAllergenKey("EGGS"))
        // "EGG" is another vocabulary's word for it, not a key here.
        assertFalse(FoodSafety.isAllergenKey("EGG"))
        assertTrue(FoodSafety.isDeclarationKey("COLORING"))
        assertFalse(FoodSafety.isDeclarationKey("WHEAT"))
        assertFalse(FoodSafety.isAllergenKey(null))
    }

    @Test
    fun noDuplicateOrOverlappingKeys() {
        assertEquals(FoodSafety.allergenKeys.size, FoodSafety.allergenKeys.toSet().size)
        assertEquals(FoodSafety.declarationKeys.size, FoodSafety.declarationKeys.toSet().size)
        // The two vocabularies must not overlap, or a stored key is ambiguous.
        assertTrue((FoodSafety.allergenKeys.toSet() intersect FoodSafety.declarationKeys.toSet()).isEmpty())
    }

    @Test
    fun cerealsAndTreeNutsAreGroupsButNeverSelectableKeys() {
        val en = FoodSafety.getDisclosures("en")
        val groups = en.allergens.map { it.group }.toSet()
        val keys = en.allergens.map { it.key }.toSet()

        assertEquals(14, groups.size)
        // The law requires naming the specific grain or nut, so the umbrella
        // group is display-only and must not be storable.
        assertFalse("CEREALS" in keys)
        assertFalse("TREE_NUTS" in keys)
        assertTrue("CEREALS" in groups && "TREE_NUTS" in groups)
    }

    @Test
    fun countsMatchTheCanonicalDatasetOnDisk() {
        val root = repoRoot() ?: return // published artifact — nothing to compare against
        assertEquals(countEntries(File(root, "data/allergens.json")), FoodSafety.allergenKeys.size)
        assertEquals(countEntries(File(root, "data/declarations.json")), FoodSafety.declarationKeys.size)
        assertEquals(28, FoodSafety.allergenKeys.size)
        assertEquals(22, FoodSafety.declarationKeys.size)
        assertEquals("MENUELLA", FoodSafety.codeScheme)
    }

    @Test
    fun versionMatchesTheRepository() {
        val root = repoRoot() ?: return
        val npm = Regex("\"version\"\\s*:\\s*\"([^\"]+)\"")
            .find(File(root, "package.json").readText())!!.groupValues[1]
        val gradle = Regex("^version=(.+)$", RegexOption.MULTILINE)
            .find(File(root, "packages/java/gradle.properties").readText())!!.groupValues[1].trim()
        assertEquals(npm, gradle, "gradle.properties and package.json disagree — one tag, one version")
    }

    // -------------------------------------------------------------- icons --

    @Test
    fun everyIconTheDataReferencesHasAGlyphAndNoneIsUnused() {
        val en = FoodSafety.getDisclosures("en")
        val referenced = (en.allergens.map { it.icon } + en.declarations.map { it.icon }).toSet()
        for (name in referenced) assertTrue(FoodSafety.getIcon(name).nodes.isNotEmpty(), name)
        assertEquals(referenced.sorted(), FoodSafety.iconNames)
    }

    @Test
    fun everyShapePaintsWithCurrentColor() {
        // Without this a glyph cannot follow the surrounding text colour, which
        // is the whole reason these are inlined rather than served as images.
        for (name in FoodSafety.iconNames) {
            for (node in FoodSafety.getIcon(name).nodes) {
                assertEquals("currentColor", node.attributes["fill"], "$name/${node.tag}")
            }
        }
    }

    @Test
    fun markupUsesSvgAttributeSpellingNotTheReactOne() {
        val all = FoodSafety.iconNames.joinToString("") { FoodSafety.iconToSvg(it) }
        assertFalse(all.contains("fillRule"))
        assertFalse(all.contains("clipRule"))
        assertContains(all, "fill-rule=\"evenodd\"")
    }

    @Test
    fun svgIsDecorativeByDefaultAndNamedOnlyWithATitle() {
        val plain = FoodSafety.iconToSvg("milk")
        assertContains(plain, "aria-hidden=\"true\"")
        assertContains(plain, "focusable=\"false\"")
        assertFalse(plain.contains("role=\"img\""))

        val titled = FoodSafety.iconToSvg("milk", title = "Milk")
        assertContains(titled, "role=\"img\"")
        assertContains(titled, "<title>Milk</title>")
        assertFalse(titled.contains("aria-hidden"))
    }

    @Test
    fun aCallerSuppliedTitleCannotInjectMarkup() {
        val svg = FoodSafety.iconToSvg("milk", title = "</title><script>alert(1)</script>")
        assertFalse(svg.contains("<script>"))
        assertContains(svg, "&lt;script&gt;")
    }

    @Test
    fun sizeAndClassReachTheRootElement() {
        val svg = FoodSafety.iconToSvg("eggs", size = 16, cssClass = "h-4 w-4")
        assertContains(svg, "width=\"16\" height=\"16\"")
        assertContains(svg, "class=\"h-4 w-4\"")
    }

    @Test
    fun anUnknownIconThrowsAndNamesWhatIsAvailable() {
        val error = assertFailsWith<IllegalArgumentException> { FoodSafety.getIcon("wine") }
        assertContains(error.message!!, "Available:")
    }
}
