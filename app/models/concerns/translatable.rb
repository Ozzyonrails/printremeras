# jsonb-backed translated attributes: `translates :name` stores {"es"=>..,"ru"=>..}
# in the `name` column and exposes `name` (current locale with fallback to es),
# `name_translations` and `name_translations=`.
module Translatable
  extend ActiveSupport::Concern

  class_methods do
    def translates(*attrs)
      attrs.each do |attr|
        define_method(attr) do |locale = I18n.locale|
          translations = self[attr] || {}
          translations[locale.to_s].presence || translations[I18n.default_locale.to_s].presence || translations.values.find(&:present?)
        end
        define_method("#{attr}_translations") { self[attr] || {} }
        define_method("#{attr}_translations=") { |hash| self[attr] = (hash || {}).to_h.transform_keys(&:to_s).transform_values { |v| v.to_s } }
        define_method("#{attr}=") { |value| self[attr] = (self[attr] || {}).merge(I18n.locale.to_s => value.to_s) }
      end
      define_method(:translated_attributes) { attrs }
    end
  end
end
