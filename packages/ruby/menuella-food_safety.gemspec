# frozen_string_literal: true

require_relative "lib/menuella/food_safety/version"

Gem::Specification.new do |spec|
  # A dash separates the namespace, an underscore joins words inside it — so
  # this gem is `Menuella::FoodSafety`, required as "menuella/food_safety".
  # A plain `menuella-food-safety` would claim to be `Menuella::Food::Safety`.
  spec.name = "menuella-food_safety"
  spec.version = Menuella::FoodSafety::VERSION
  spec.authors = ["Menuella"]
  spec.email = ["hello@menuella.com"]

  spec.summary = "Open allergen and additive vocabulary for restaurant menus."
  spec.description = <<~TEXT.strip
    28 allergen keys from EU Reg. 1169/2011 Annex II, 22 declarations, footnote
    codes, 15 icons and six languages. Semantic keys instead of
    country-specific numbers: store the key, render the code, never the
    reverse. No runtime dependencies.
  TEXT

  spec.homepage = "https://www.menuella.com/food-safety"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => "https://github.com/menuella/food-safety",
    "changelog_uri" => "https://github.com/menuella/food-safety/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/menuella/food-safety/issues",
    "documentation_uri" => "https://rubydoc.info/gems/menuella-food_safety",
    # This gem is public, so the guard is about accidents rather than secrecy:
    # a stray `gem push --host` cannot send it somewhere else.
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true",
  }

  # Listed explicitly rather than by `git ls-files`, so the packaged gem is the
  # same whether it is built from a checkout, a tarball or a CI workspace — and
  # so a stray file in the working tree can never end up published.
  spec.files = Dir[
    "lib/**/*.rb",
    "lib/menuella/food_safety/data/**/*.json",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
  ]
  spec.require_paths = ["lib"]

  # No runtime dependencies. `json` is a default gem, which is the whole reason
  # this binding ships the canonical JSON rather than generated source.
end
