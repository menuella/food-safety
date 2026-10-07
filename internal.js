// Shared by the generated entry points. Not part of the public API: the
// package's `exports` map does not expose this file.

/**
 * Bundles are module-level singletons shared by every caller, so a consumer
 * that mutated one would corrupt the dataset for the whole process.
 */
export const deepFreeze = (value) => {
  if (value !== null && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value)
    for (const inner of Object.values(value)) deepFreeze(inner)
  }
  return value
}

/** The one error every entry point throws for a locale without a bundle. */
export const unsupportedLocale = (locale, locales) => {
  const shown = typeof locale === "string" ? `"${locale}"` : String(locale)
  const error = new Error(
    `No disclosures for locale ${shown}. Available: ${locales.join(", ")}.`,
  )
  error.code = "ERR_UNSUPPORTED_LOCALE"
  return error
}
