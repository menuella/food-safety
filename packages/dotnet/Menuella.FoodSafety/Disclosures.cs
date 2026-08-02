using System.Collections.Concurrent;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

namespace Menuella.FoodSafety;

/// <summary>
/// The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens and
/// the Menuella declarations, in six languages.
///
/// <para>
/// This is the same dataset the <c>@menuella/food-safety</c> npm package ships,
/// read from the same JSON — not a C# transcription of it. A transcription is a
/// second copy, and a second copy drifts.
/// </para>
///
/// <para>
/// It does NOT do i18n. Hand it the locale your app already resolved; it will
/// not sniff, negotiate, or quietly fall back.
/// </para>
/// </summary>
public static class Disclosures
{
    private static readonly ConcurrentDictionary<string, DisclosureSet> Cache = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Locales with a prebuilt bundle.</summary>
    public static IReadOnlyList<string> Locales { get; } = ["de", "en", "es", "fr", "it", "tr"];

    /// <summary>The locale a bundle falls back to for anything it does not itself carry.</summary>
    public const string FallbackLocale = "en";

    /// <summary>The footnote-code scheme these codes belong to.</summary>
    public static string CodeScheme { get; } =
        Resources.Read<CodesDto>("codes.json", FoodSafetyJsonContext.Default.CodesDto).Scheme;

    /// <summary>True when the value is a locale with a bundle.</summary>
    public static bool IsLocale(string? value) =>
        value is not null && Locales.Contains(value, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Every disclosure for a locale, ready to render. Bundles are parsed once
    /// and cached; the returned lists are read-only, so no caller can corrupt
    /// the dataset for another.
    /// </summary>
    /// <exception cref="ArgumentException">The locale has no bundle.</exception>
    public static DisclosureSet Get(string locale)
    {
        ArgumentNullException.ThrowIfNull(locale);

        if (!IsLocale(locale))
        {
            throw new ArgumentException(
                $"No disclosures for locale \"{locale}\". Available: {string.Join(", ", Locales)}.",
                nameof(locale));
        }

        return Cache.GetOrAdd(locale.ToLowerInvariant(), static key =>
        {
            var dto = Resources.Read<BundleDto>($"bundles.{key}.json", FoodSafetyJsonContext.Default.BundleDto);
            return new DisclosureSet(
                dto.Locale,
                dto.FallbackLocale,
                dto.Allergens.ConvertAll(a => new Allergen(
                    a.Key, a.Group, a.IsMember, a.Icon, a.Name, a.Declaration, a.Description)).AsReadOnly(),
                dto.Declarations.ConvertAll(d => new Declaration(
                    d.Key, d.Category, d.Icon, d.Name, d.Description)).AsReadOnly());
        });
    }

    /// <summary>Every selectable allergen key. Derived from the data, never hand-listed.</summary>
    public static IReadOnlyList<string> AllergenKeys { get; } =
        Get(FallbackLocale).Allergens.Select(a => a.Key).ToList().AsReadOnly();

    /// <summary>Every declaration key.</summary>
    public static IReadOnlyList<string> DeclarationKeys { get; } =
        Get(FallbackLocale).Declarations.Select(d => d.Key).ToList().AsReadOnly();

    private static readonly HashSet<string> AllergenSet = new(AllergenKeys, StringComparer.OrdinalIgnoreCase);
    private static readonly HashSet<string> DeclarationSet = new(DeclarationKeys, StringComparer.OrdinalIgnoreCase);

    /// <summary>True when the value is a current allergen key. Retired keys return false.</summary>
    public static bool IsAllergenKey(string? value) => value is not null && AllergenSet.Contains(value);

    /// <summary>True when the value is a current declaration key.</summary>
    public static bool IsDeclarationKey(string? value) => value is not null && DeclarationSet.Contains(value);
}

internal static class Resources
{
    private static readonly Assembly Assembly = typeof(Resources).Assembly;

    internal static Stream Open(string logicalName) =>
        Assembly.GetManifestResourceStream(logicalName)
            ?? throw new InvalidOperationException(
                $"Embedded resource \"{logicalName}\" is missing. The package was built without its data, " +
                "which means the .csproj EmbeddedResource globs no longer match data/.");

    internal static T Read<T>(string logicalName, JsonTypeInfo<T> typeInfo)
    {
        using var stream = Assembly.GetManifestResourceStream(logicalName)
            ?? throw new InvalidOperationException(
                $"Embedded resource \"{logicalName}\" is missing. The package was built without its data, " +
                "which means the .csproj EmbeddedResource globs no longer match data/.");

        return JsonSerializer.Deserialize(stream, typeInfo)
            ?? throw new InvalidOperationException($"Embedded resource \"{logicalName}\" deserialized to null.");
    }
}

/// <summary>
/// Source-generated contexts, so the package works under trimming and Native AOT.
/// Reflection-based serialization would be silently wrong there: the linker
/// removes the property setters and every field comes back null.
/// </summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(BundleDto))]
[JsonSerializable(typeof(CodesDto))]
internal sealed partial class FoodSafetyJsonContext : JsonSerializerContext;
