# Slugs are derived from the name and never typed by hand: they are a URL detail, not
# something a shop owner should have to think about. Cyrillic is transliterated, and a
# collision (or a name that yields nothing usable) gets a short suffix.
module Sluggable
  extend ActiveSupport::Concern

  class_methods do
    def slug_source(attribute)
      before_validation { self.slug = generate_slug(send(attribute)) if slug.blank? }
    end
  end

  private

  def generate_slug(source)
    base = transliterate(source).presence || self.class.name.underscore.dasherize
    candidate = base
    suffix = 0
    while self.class.where(slug: candidate).where.not(id: id).exists?
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    candidate
  end

  def transliterate(source)
    text = source.to_s.strip
    return "" if text.blank?
    # ru rules come from config/initializers/transliteration.rb; :es needs no special casing.
    I18n.transliterate(text, locale: :ru).parameterize.presence || SecureRandom.alphanumeric(8).downcase
  end
end
