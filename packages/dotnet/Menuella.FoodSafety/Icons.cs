using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Menuella.FoodSafety;

/// <summary>
/// The 15 disclosure glyphs.
///
/// <para>
/// Every shape paints with <c>currentColor</c>, so a glyph inherits the
/// surrounding text colour and follows a light/dark theme with no second asset.
/// That is why these are meant to be inlined rather than served as an image: an
/// image cannot inherit colour.
/// </para>
///
/// <para>
/// These glyphs carry legal meaning. Render one ALONGSIDE its declaration text,
/// never instead of it — <see cref="ToSvg"/> therefore emits
/// <c>aria-hidden</c> unless you pass a title.
/// </para>
/// </summary>
public static class Icons
{
    private static readonly Lazy<IReadOnlyDictionary<string, Icon>> All = new(Load);

    /// <summary>Icon names that have a glyph.</summary>
    ///
    /// <remarks>
    /// An expression-bodied property, NOT <c>{ get; } = All.Value…</c>. A static
    /// field initializer would force <see cref="Load"/> during type
    /// initialization, and static initializers run in declaration order — so
    /// <c>SvgAttribute</c>, declared below, would still be null when Load read
    /// it. That surfaced as a NullReferenceException inside a
    /// TypeInitializationException, which points at the wrong line entirely.
    /// Deferring means every static field is in place before Load ever runs.
    /// </remarks>
    public static IReadOnlyList<string> Available =>
        All.Value.Keys.OrderBy(n => n, StringComparer.Ordinal).ToList().AsReadOnly();

    /// <summary>
    /// The glyph as data, for callers that build elements rather than markup.
    /// </summary>
    /// <exception cref="ArgumentException">The name has no glyph.</exception>
    public static Icon Get(string name)
    {
        ArgumentNullException.ThrowIfNull(name);

        return All.Value.TryGetValue(name, out var icon)
            ? icon
            : throw new ArgumentException(
                $"No icon named \"{name}\". Available: {string.Join(", ", Available)}.", nameof(name));
    }

    /// <summary>
    /// The glyph as an <c>&lt;svg&gt;</c> string, for templates that interpolate
    /// markup — Razor, e-mail, PDF.
    /// </summary>
    /// <param name="name">The glyph name, from an entry's <c>Icon</c>.</param>
    /// <param name="size">Rendered width and height in px.</param>
    /// <param name="cssClass">Added to the root element.</param>
    /// <param name="title">
    /// Gives the glyph an accessible name and <c>role="img"</c>. Omit it when the
    /// declaration text sits beside the icon: then the glyph is decoration, stays
    /// <c>aria-hidden</c>, and the text carries the meaning. That is the correct
    /// default on a legal surface.
    /// </param>
    /// <exception cref="ArgumentException">The name has no glyph.</exception>
    public static string ToSvg(string name, int size = 24, string? cssClass = null, string? title = null)
    {
        var icon = Get(name);
        var sb = new StringBuilder(512);

        sb.Append("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"")
          .Append(WebUtility.HtmlEncode(icon.ViewBox))
          .Append("\" width=\"").Append(size)
          .Append("\" height=\"").Append(size)
          .Append("\" fill=\"none\"");

        if (!string.IsNullOrEmpty(cssClass))
        {
            sb.Append(" class=\"").Append(WebUtility.HtmlEncode(cssClass)).Append('"');
        }

        if (string.IsNullOrEmpty(title))
        {
            sb.Append(" aria-hidden=\"true\" focusable=\"false\">");
        }
        else
        {
            sb.Append(" role=\"img\"><title>").Append(WebUtility.HtmlEncode(title)).Append("</title>");
        }

        foreach (var node in icon.Nodes)
        {
            sb.Append('<').Append(node.Tag);
            foreach (var (key, value) in node.Attributes)
            {
                sb.Append(' ').Append(key).Append("=\"").Append(WebUtility.HtmlEncode(value)).Append('"');
            }
            sb.Append("/>");
        }

        return sb.Append("</svg>").ToString();
    }

    // The JSON carries React attribute spelling; markup needs the SVG one.
    private static readonly Dictionary<string, string> SvgAttribute = new(StringComparer.Ordinal)
    {
        ["fillRule"] = "fill-rule",
        ["clipRule"] = "clip-rule",
    };

    private static IReadOnlyDictionary<string, Icon> Load()
    {
        // JsonDocument rather than typed deserialization: a node is
        // ["path", { … }] — a heterogeneous array whose first element is a
        // string and second an object. Modelling that in the type system costs
        // a custom converter and a DTO that exist only to be unwrapped again.
        // Reading the DOM is shorter, and stays trim/AOT-safe (no reflection).
        using var stream = Resources.Open("icons.json");
        using var doc = JsonDocument.Parse(stream);

        var result = new Dictionary<string, Icon>(StringComparer.Ordinal);
        foreach (var icon in doc.RootElement.EnumerateObject())
        {
            var viewBox = icon.Value.GetProperty("viewBox").GetString()
                ?? throw new InvalidOperationException($"icons.json: \"{icon.Name}\" has no viewBox.");

            var nodes = new List<IconNode>();
            foreach (var node in icon.Value.GetProperty("nodes").EnumerateArray())
            {
                // Tag first, attributes second. Anything else means the
                // generator changed shape — failing loudly here beats rendering
                // a glyph with shapes silently missing.
                if (node.GetArrayLength() != 2)
                {
                    throw new InvalidOperationException($"icons.json: malformed node in \"{icon.Name}\".");
                }

                var tag = node[0].GetString()
                    ?? throw new InvalidOperationException($"icons.json: node tag is not a string in \"{icon.Name}\".");

                var attrs = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var attr in node[1].EnumerateObject())
                {
                    var key = SvgAttribute.TryGetValue(attr.Name, out var svgKey) ? svgKey : attr.Name;
                    attrs[key] = attr.Value.GetString() ?? string.Empty;
                }

                nodes.Add(new IconNode(tag, attrs));
            }

            result[icon.Name] = new Icon(viewBox, nodes.AsReadOnly());
        }

        return result;
    }
}
