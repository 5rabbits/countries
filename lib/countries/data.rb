module ISO3166
  ##
  # Handles building the in memory store of countries data
  class Data
    @@cache_dir = [File.dirname(__FILE__), 'cache']
    @@data_dir = [File.dirname(__FILE__), 'data']
    @@cache = {}
    @@registered_data = {}
    @@locales = []

    def initialize(alpha2)
      @alpha2 = alpha2.to_s.upcase
    end

    def call
      self.class.update_cache[@alpha2]
    end

    class << self
      def cache_dir
        @@cache_dir
      end

      def data_dir
        @@data_dir
      end

      def cache_dir=(value)
        @@cache_dir = value
      end

      def register(data)
        alpha2 = data[:alpha2].upcase
        @@registered_data[alpha2] = \
          data.each_with_object({}) { |(k, v), a| a[k.to_s] = v }
        @@registered_data[alpha2]['translations'] = \
          Translations.new.merge(data[:translations] || {})
        @@cache = cache.merge(@@registered_data)
      end

      def unregister(alpha2)
        alpha2 = alpha2.to_s.upcase
        @@cache.delete(alpha2)
        @@registered_data.delete(alpha2)
      end

      def cache
        update_cache
      end

      def reset
        @@cache = {}
        @@registered_data = {}
        ISO3166.configuration.loaded_locales = []
      end

      def codes
        load_data!
        loaded_codes
      end

      def update_cache
        load_data!
        sync_translations!
        @@cache
      end

      def locales
        load_locales
      end

      def locale(locale_code)
        find_locale_code locale_code
      end

      def load_data!
        return @@cache unless load_required?
        @@cache = load_cache %w(countries.json)
        @@_country_codes = @@cache.keys
        @@locales = load_locales
        @@cache = @@cache.merge(@@registered_data)
        @@cache
      end

      def sync_translations!
        return unless cache_flush_required?

        locales_to_remove.each do |locale|
          unload_translations(locale)
        end

        locales_to_load.each do |locale|
          load_translations(locale)
        end
      end

      private

      def load_required?
        @@cache.empty?
      end

      def loaded_codes
        @@cache.keys
      end

      # Codes that we have translations for in dataset
      def internal_codes
        @@_country_codes - @@registered_data.keys
      end

      def cache_flush_required?
        !locales_to_load.empty? || !locales_to_remove.empty?
      end

      def locales_to_load
        requested_locales - loaded_locales
      end

      def locales_to_remove
        loaded_locales - requested_locales
      end

      def requested_locales
        ISO3166.configuration.locales.map { |l| l.to_s.downcase }
      end

      def loaded_locales
        ISO3166.configuration.loaded_locales.map { |l| l.to_s.downcase }
      end

      def load_translations(locale)
        locale_names = load_cache(['locales', "#{locale}.json"])
        internal_codes.each do |alpha2|
          @@cache[alpha2]['translations'] ||= Translations.new
          @@cache[alpha2]['translations'][locale] = locale_names[alpha2].freeze
          @@cache[alpha2]['translated_names'] = @@cache[alpha2]['translations'].values.freeze
        end
        ISO3166.configuration.loaded_locales << locale
      end

      def unload_translations(locale)
        internal_codes.each do |alpha2|
          @@cache[alpha2]['translations'].delete(locale)
          @@cache[alpha2]['translated_names'] = @@cache[alpha2]['translations'].values.freeze
        end
        ISO3166.configuration.loaded_locales.delete(locale)
      end

      def load_cache(file_array)
        file_path = datafile_path(file_array)
        File.exist?(file_path) ? JSON.parse(File.binread(file_path)) : {}
      end

      def datafile_path(file_array)
        File.join([@@cache_dir] + file_array)
      end

      def load_locales
        return @@locales unless @@locales.empty?
        locales = Dir.glob(locale_data_path)
        @@locales = locales.map do |locale|
          File.basename locale, '.yaml'
        end
      end

      def locale_data_path
        File.join(data_dir, 'locale', '*.yaml')
      end

      def find_locale_code(code)
        return unless File.exist?(locale_path(code))
        YAML.load_file locale_path(code)
      end

      def locale_path(code)
        File.join(File.dirname(__FILE__), 'data', 'locale', "#{code}.yaml")
      end
    end
  end
end
