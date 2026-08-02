using System.Text.Json;
using Menuella.FoodSafety;

namespace Menuella.FoodSafety.Tests;

public class IconsTests
{
    [Fact]
    public void EveryIconTheDataReferencesHasAGlyph()
    {
        var referenced = Disclosures.Get("en").Allergens.Select(a => a.Icon)
            .Concat(Disclosures.Get("en").Declarations.Select(d => d.Icon))
            .Distinct();

        foreach (var name in referenced)
        {
            var icon = Icons.Get(name);
            Assert.Equal("0 0 24 24", icon.ViewBox);
            Assert.NotEmpty(icon.Nodes);
        }

        // The reverse too: a glyph nothing references is dead weight in the
        // package, and usually means a rename landed on one side only.
        Assert.Equal(referenced.OrderBy(n => n, StringComparer.Ordinal), Icons.Available);
    }

    [Fact]
    public void EveryShapePaintsWithCurrentColor()
    {
        // Without this a glyph cannot follow the surrounding text colour, which
        // is the entire reason these are inlined rather than served as images.
        foreach (var name in Icons.Available)
        {
            foreach (var node in Icons.Get(name).Nodes)
            {
                Assert.True(node.Attributes.TryGetValue("fill", out var fill), $"{name}: <{node.Tag}> has no fill");
                Assert.Equal("currentColor", fill);
            }
        }
    }

    [Fact]
    public void ShapeCountsMatchTheJsonOnDisk()
    {
        // Same reasoning as the key-count test: catches the embedded resource
        // silently going stale against data/icons.json.
        var path = Path.Combine(DisclosuresTests.FindRepoRoot(), "data", "icons.json");
        using var doc = JsonDocument.Parse(File.ReadAllText(path));

        foreach (var icon in doc.RootElement.EnumerateObject())
        {
            var onDisk = icon.Value.GetProperty("nodes").GetArrayLength();
            Assert.Equal(onDisk, Icons.Get(icon.Name).Nodes.Count);
        }

        Assert.Equal(doc.RootElement.EnumerateObject().Count(), Icons.Available.Count);
    }

    [Fact]
    public void MarkupUsesSvgAttributeSpellingNotTheReactOne()
    {
        // The JSON carries fillRule/clipRule because its first consumer is React.
        // Emitting those into markup produces attributes no SVG renderer reads —
        // and the shape still draws, just without the even-odd rule, so the bug
        // is a subtly wrong glyph rather than a missing one.
        var all = string.Concat(Icons.Available.Select(n => Icons.ToSvg(n)));
        Assert.DoesNotContain("fillRule", all);
        Assert.DoesNotContain("clipRule", all);
        Assert.Contains("fill-rule=\"evenodd\"", all);
    }

    [Fact]
    public void ToSvgIsDecorativeByDefaultAndNamedOnlyWithATitle()
    {
        var plain = Icons.ToSvg("milk");
        Assert.Contains("aria-hidden=\"true\"", plain);
        Assert.Contains("focusable=\"false\"", plain);
        Assert.DoesNotContain("role=\"img\"", plain);

        var titled = Icons.ToSvg("milk", title: "Milk");
        Assert.Contains("role=\"img\"", titled);
        Assert.Contains("<title>Milk</title>", titled);
        Assert.DoesNotContain("aria-hidden", titled);
    }

    [Fact]
    public void ACallerSuppliedTitleCannotInjectMarkup()
    {
        var svg = Icons.ToSvg("milk", title: "</title><script>alert(1)</script>");
        Assert.DoesNotContain("<script>", svg);
        Assert.Contains("&lt;script&gt;", svg);
    }

    [Fact]
    public void SizeAndClassReachTheRootElement()
    {
        var svg = Icons.ToSvg("eggs", size: 16, cssClass: "h-4 w-4");
        Assert.Contains("width=\"16\" height=\"16\"", svg);
        Assert.Contains("class=\"h-4 w-4\"", svg);
    }

    [Fact]
    public void AnUnknownIconThrowsAndNamesWhatIsAvailable()
    {
        var error = Assert.Throws<ArgumentException>(() => Icons.Get("wine"));
        Assert.Contains("Available:", error.Message);
    }
}
