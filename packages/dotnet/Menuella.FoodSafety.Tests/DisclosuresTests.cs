using System.Text.Json;
using Menuella.FoodSafety;

namespace Menuella.FoodSafety.Tests;

/// <summary>
/// Behaviour of the published surface. The DATA is checked by the repo's
/// scripts/verify.mjs; these cover the code that hands it out, plus the one
/// thing a second language binding can get wrong that the first cannot: drifting
/// from the JSON it is supposed to be reading.
/// </summary>
public class DisclosuresTests
{
    [Fact]
    public void EveryLocaleResolves()
    {
        foreach (var locale in Disclosures.Locales)
        {
            var set = Disclosures.Get(locale);
            Assert.Equal(locale, set.Locale);
            Assert.NotEmpty(set.Allergens);
            Assert.NotEmpty(set.Declarations);
            Assert.All(set.Allergens, a => Assert.False(string.IsNullOrWhiteSpace(a.Declaration)));
            Assert.All(set.Declarations, d => Assert.False(string.IsNullOrWhiteSpace(d.Name)));
        }
    }

    [Fact]
    public void LocaleLookupIsCaseInsensitiveButAnUnknownOneThrows()
    {
        Assert.Equal("de", Disclosures.Get("DE").Locale);

        var error = Assert.Throws<ArgumentException>(() => Disclosures.Get("nope"));
        Assert.Contains("Available:", error.Message);
    }

    [Fact]
    public void TheSameBundleIsReturnedEachTime()
    {
        // Parsed once and cached — a fresh parse per call would be a silent
        // per-request allocation on a hot path.
        Assert.Same(Disclosures.Get("de"), Disclosures.Get("de"));
    }

    [Fact]
    public void GuardsRejectKeysThatAreNotInTheVocabulary()
    {
        Assert.True(Disclosures.IsAllergenKey("WHEAT"));
        Assert.True(Disclosures.IsAllergenKey("EGGS"));
        // "EGG" is Google's word for it, not ours. Core maps EGGS -> EGG only on
        // the way out to Google Business Profile.
        Assert.False(Disclosures.IsAllergenKey("EGG"));
        Assert.True(Disclosures.IsDeclarationKey("COLORING"));
        Assert.False(Disclosures.IsDeclarationKey("WHEAT"));
        Assert.False(Disclosures.IsAllergenKey(null));
    }

    [Fact]
    public void KeyCountsMatchTheJsonOnDisk()
    {
        // The point of this test: this binding EMBEDS the same JSON the npm
        // package ships, so if the .csproj globs ever stop matching data/, the
        // assembly would ship stale or partial data and every other test here
        // would still pass. Reading the file directly is the only way to catch
        // that from inside the test suite.
        var repoRoot = FindRepoRoot();
        using var doc = JsonDocument.Parse(File.ReadAllText(Path.Combine(repoRoot, "data", "allergens.json")));
        var onDisk = doc.RootElement.GetArrayLength();

        Assert.Equal(onDisk, Disclosures.AllergenKeys.Count);
        Assert.Equal(28, Disclosures.AllergenKeys.Count);
        Assert.Equal(22, Disclosures.DeclarationKeys.Count);
        Assert.Equal("MENUELLA", Disclosures.CodeScheme);
    }

    [Fact]
    public void CerealsAndTreeNutsAreGroupsButNotSelectableKeys()
    {
        var en = Disclosures.Get("en");
        var groups = en.Allergens.Select(a => a.Group).Distinct().ToList();
        var keys = en.Allergens.Select(a => a.Key).ToHashSet();

        Assert.Equal(14, groups.Count);
        // The law requires naming the specific grain or nut, so the umbrella
        // group is display-only and must never be storable.
        Assert.DoesNotContain("CEREALS", keys);
        Assert.DoesNotContain("TREE_NUTS", keys);
        Assert.Contains("CEREALS", groups);
        Assert.Contains("TREE_NUTS", groups);
    }

    internal static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "data", "allergens.json")))
        {
            dir = dir.Parent;
        }
        return dir?.FullName ?? throw new InvalidOperationException("Could not locate the repo root from the test binary.");
    }
}
