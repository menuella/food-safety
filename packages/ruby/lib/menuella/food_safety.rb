# frozen_string_literal: true

require "json"
require "monitor"

require_relative "food_safety/version"

module Menuella
  # The Menuella food-safety vocabulary: EU Reg. 1169/2011 Annex II allergens
  # and the Menuella declarations, in six languages.
  #
  # Semantic keys instead of country-specific numbers — store the key, render
  # the code, never the reverse.
  #
  #   de = Menuella::FoodSafety.disclosures("de")
  #   de.allergens.find { _1.key == "WHEAT" }.declaration
  #   # => "Enthält Getreide und glutenhaltige Erzeugnisse"
  #
  # This module does *no* i18n. Hand it the locale your application already
  # resolved; it will not sniff the environment, negotiate, or quietly fall
  # back.
  #
  # Everything it returns is frozen. The dataset is a shared constant, and a
  # caller that could mutate one bundle would be mutating every other caller's
  # copy in the same process.
  module FoodSafety
    # Base class for everything this module raises, so a caller can rescue the
    # whole surface without naming each one.
    class Error < StandardError; end

    # The locale has no bundle. FoodSafety.locales lists the ones that do.
    class UnsupportedLocaleError < Error
      attr_reader :locale

      def initialize(locale)
        @locale = locale
        super("no disclosures for locale #{locale.inspect} " \
              "(available: #{FoodSafety.locales.join(', ')})")
      end
    end

    # The name has no glyph. FoodSafety.icon_names lists the ones that do.
    class UnknownIconError < Error
      attr_reader :name

      def initialize(name)
        @name = name
        super("no icon named #{name.inspect}")
      end
    end

    # One allergen, resolved for a locale.
    #
    # +key+ is what a product row stores. +group+ is its LMIV group; +CEREALS+
    # and +TREE_NUTS+ are groups but never keys, because the law requires
    # naming the specific grain or nut. +declaration+ is the sentence with
    # legal force — the one that must reach the guest.
    Allergen = Data.define(:key, :group, :is_member, :icon, :name, :declaration, :description) do
      # Ruby spells a predicate with a question mark; the dataset spells it
      # +isMember+. Both names reach the same field.
      alias_method :member?, :is_member
    end

    # One declaration — an additive, beverage or product note — for a locale.
    Declaration = Data.define(:key, :category, :icon, :name, :description)

    # Every disclosure for one locale, ready to render.
    Disclosures = Data.define(:locale, :fallback_locale, :allergens, :declarations)

    # The footnote-code scheme: letters for allergens, numbers for declarations.
    #
    # Codes are what a printed menu shows. Keys are what a database stores, and
    # the projection only runs in that direction — a code is a rendering detail
    # that varies by region and template, a key is not.
    Codes = Data.define(:scheme, :allergens, :declarations)

    # A single shape in a glyph. +attributes+ uses SVG spelling
    # (<tt>fill-rule</tt>, not <tt>fillRule</tt>) and is sorted by name, so
    # rendered markup is byte-stable.
    IconNode = Data.define(:tag, :attributes)

    # A glyph as data, for callers that build shapes rather than markup.
    Icon = Data.define(:view_box, :nodes)

    DATA_DIR = File.join(__dir__, "food_safety", "data").freeze
    private_constant :DATA_DIR

    # The JSON carries React attribute spelling, because its first consumer is
    # React. Markup needs the SVG one — and an unmapped name still draws, just
    # without the even-odd rule, so the bug would be a subtly wrong glyph
    # rather than a missing one.
    SVG_ATTRIBUTE = { "fillRule" => "fill-rule", "clipRule" => "clip-rule" }.freeze
    private_constant :SVG_ATTRIBUTE

    ESCAPES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#39;" }.freeze
    private_constant :ESCAPES

    # A Monitor, not a Mutex: #allergen_keys memoises a value it computes by
    # calling #disclosures, which memoises too. A Mutex is not reentrant, so
    # that nesting would deadlock on the first call rather than on some rare
    # race — the kind of bug that passes every test written after it.
    LOCK = Monitor.new
    private_constant :LOCK

    class << self
      # Locales with a prebuilt bundle.
      def locales
        @locales ||= %w[de en es fr it tr].freeze
      end

      # The locale a bundle falls back to for anything it does not itself carry.
      def fallback_locale
        "en"
      end

      # Every disclosure for +locale+, ready to render.
      #
      # Raises UnsupportedLocaleError rather than falling back: a silently wrong
      # language on an allergen panel is worse than a loud failure. The caller
      # knows which locales it supports, and #locale? is there to ask.
      def disclosures(locale)
        raise UnsupportedLocaleError, locale unless locale?(locale)

        memo(:bundles, locale) do
          raw = read("bundles/#{locale}")
          Disclosures.new(
            locale: raw.fetch("locale").freeze,
            fallback_locale: raw.fetch("fallbackLocale").freeze,
            allergens: raw.fetch("allergens").map { |a|
              Allergen.new(
                key: a.fetch("key").freeze,
                group: a.fetch("group").freeze,
                is_member: a.fetch("isMember"),
                icon: a.fetch("icon").freeze,
                name: a.fetch("name").freeze,
                declaration: a.fetch("declaration").freeze,
                description: a.fetch("description").freeze,
              )
            }.freeze,
            declarations: raw.fetch("declarations").map { |d|
              Declaration.new(
                key: d.fetch("key").freeze,
                category: d.fetch("category").freeze,
                icon: d.fetch("icon").freeze,
                name: d.fetch("name").freeze,
                description: d.fetch("description").freeze,
              )
            }.freeze,
          )
        end
      end

      # The footnote-code scheme.
      def codes
        memo(:codes) do
          raw = read("codes")
          Codes.new(
            scheme: raw.fetch("scheme").freeze,
            allergens: deep_freeze(raw.fetch("allergens")),
            declarations: deep_freeze(raw.fetch("declarations")),
          )
        end
      end

      # The scheme #codes belong to.
      def code_scheme
        codes.scheme
      end

      # Every selectable allergen key, in canonical order.
      #
      # Derived from the dataset, never hand-listed. Keys are
      # locale-independent, so this reads the fallback bundle rather than
      # taking a locale argument.
      def allergen_keys
        memo(:allergen_keys) { disclosures(fallback_locale).allergens.map(&:key).freeze }
      end

      # Every declaration key, in canonical order.
      def declaration_keys
        memo(:declaration_keys) { disclosures(fallback_locale).declarations.map(&:key).freeze }
      end

      # Every icon name that has a glyph, sorted.
      def icon_names
        memo(:icon_names) { icons.keys.sort.freeze }
      end

      # True when +value+ is a locale with a bundle.
      def locale?(value)
        locales.include?(value)
      end

      # True when +value+ is a current allergen key. Retired keys and
      # display-only groups return false.
      def allergen_key?(value)
        allergen_keys.include?(value)
      end

      # True when +value+ is a current declaration key.
      def declaration_key?(value)
        declaration_keys.include?(value)
      end

      # The glyph named +name+, as data.
      #
      # Every shape paints with +currentColor+, so a glyph inherits the
      # surrounding text colour and follows a light or dark theme with no
      # second asset.
      def icon(name)
        icons.fetch(name) { raise UnknownIconError, name }
      end

      # The glyph named +name+ as an <tt><svg></tt> string, for anything that
      # interpolates markup — server-rendered HTML, e-mail, PDF.
      #
      # Decorative by default: emits +aria-hidden+ unless +title:+ is given,
      # which switches it to <tt>role="img"</tt> with a <tt><title></tt>. These
      # glyphs carry legal meaning, so render one *alongside* its declaration
      # text, never instead of it — the safe default is the free one.
      def icon_to_svg(name, size: 24, css_class: nil, title: nil)
        glyph = icon(name)

        out = +%(<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{escape(glyph.view_box)}")
        out << %( width="#{size.to_i}" height="#{size.to_i}" fill="none")
        out << %( class="#{escape(css_class)}") if css_class && !css_class.empty?

        out << if title && !title.empty?
                 %( role="img"><title>#{escape(title)}</title>)
               else
                 %( aria-hidden="true" focusable="false">)
               end

        glyph.nodes.each do |node|
          out << "<#{node.tag}"
          node.attributes.each { |key, value| out << %( #{key}="#{escape(value)}") }
          out << "/>"
        end

        out << "</svg>"
        out.freeze
      end

      # The raw packaged JSON for +name+, for tooling that wants the dataset
      # rather than the objects. Returns a fresh string each call.
      def dataset(name)
        File.read(File.join(DATA_DIR, "#{name.sub(/\.json\z/, '')}.json"), encoding: "UTF-8")
      end

      private

      def icons
        memo(:icons) do
          read("icons").to_h { |name, glyph|
            [
              name.freeze,
              Icon.new(
                view_box: glyph.fetch("viewBox").freeze,
                nodes: glyph.fetch("nodes").map { |tag, attributes|
                  IconNode.new(
                    tag: tag.freeze,
                    # Sorted so the markup is deterministic. Ruby preserves Hash
                    # insertion order, so this would happen to be stable — but
                    # it would then depend on the order the generator wrote the
                    # JSON in, which is not a contract anyone stated.
                    attributes: attributes
                      .to_h { |k, v| [(SVG_ATTRIBUTE[k] || k).freeze, v.freeze] }
                      .sort.to_h.freeze,
                  )
                }.freeze,
              ),
            ]
          }.freeze
        end
      end

      def read(name)
        JSON.parse(File.read(File.join(DATA_DIR, "#{name}.json"), encoding: "UTF-8"))
      end

      # Memoised behind a lock. Without it two threads racing on first call
      # would each parse the file and one would win — harmless here, but only
      # by luck, and #disclosures is exactly the kind of thing a web server
      # calls from every request thread at once.
      def memo(bucket, key = nil)
        LOCK.synchronize do
          store = (@memo ||= {})[bucket] ||= {}
          store.fetch(key) { store[key] = yield }
        end
      end

      def deep_freeze(hash)
        hash.to_h { |k, v| [k.freeze, v.freeze] }.freeze
      end

      # The path data is ours, but +icon_to_svg+'s title and class are
      # caller-supplied and land in markup.
      def escape(value)
        value.to_s.gsub(/[&<>"']/, ESCAPES)
      end
    end
  end
end
