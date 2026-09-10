class Template < ApplicationRecord
  include Translatable
  include Sluggable
  translates :name, :description

  KINDS = %w[t-shirt hoodie sweatshirt tank-top long-sleeve tote-bag].freeze

  has_many :print_areas, -> { order(:side) }, dependent: :destroy, inverse_of: :template
  has_many :template_sizes, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :template
  has_many :catalog_items, dependent: :restrict_with_error
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error

  accepts_nested_attributes_for :template_sizes, allow_destroy: true

  validates :kind, inclusion: { in: KINDS }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :color_name, presence: true
  validates :color_hex, format: { with: /\A#[0-9a-fA-F]{6}\z/ }
  validates :base_price_cents, :print_price_one_side_cents, :print_price_two_sides_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :name_present_in_default_locale

  slug_source :name

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def print_area(side) = print_areas.find { |a| a.side == side.to_s }
  def front_area = print_area(:front)
  def print_price_for(sides)
    sides.to_i >= 2 ? print_price_two_sides_cents : (sides.to_i == 1 ? print_price_one_side_cents : 0)
  end

  def ready_for_sale?
    active? && print_areas.any? { |a| a.mockup.attached? } && template_sizes.any?
  end

  private

  def name_present_in_default_locale
    errors.add(:name, :blank) if name_translations[I18n.default_locale.to_s].blank?
  end
end
