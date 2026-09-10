class CatalogItem < ApplicationRecord
  include Translatable
  translates :title, :description

  belongs_to :template
  has_many :placements, as: :placeable, dependent: :destroy
  has_many :cart_items, dependent: :nullify
  has_many :order_items, dependent: :nullify
  has_one_attached :preview, service: ApplicationRecord.public_storage do |attachable|
    attachable.variant :card, resize_to_limit: [ 600, 600 ], format: :webp, saver: { quality: 82 }, preprocessed: true
    attachable.variant :large, resize_to_limit: [ 1200, 1200 ], format: :webp, saver: { quality: 85 }, preprocessed: true
  end

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :title_present_in_default_locale

  before_validation { self.slug = slug.presence || title_translations.values.first.to_s.parameterize }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :id) }

  def sides_count = placements.map(&:print_area_id).uniq.size

  private

  def title_present_in_default_locale
    errors.add(:title, :blank) if title_translations[I18n.default_locale.to_s].blank?
  end
end
