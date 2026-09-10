class Template < ApplicationRecord
  include Translatable
  include Sluggable
  translates :name, :description

  KINDS = %w[t-shirt hoodie sweatshirt tank-top long-sleeve tote-bag].freeze

  # A fixed palette keeps the colour picker international: the label is translated, the hex
  # is what gets stored and drawn. A shop can still type its own name for a specific shade.
  PALETTE = {
    "white" => "#ffffff", "black" => "#111111", "grey" => "#9aa0a6", "navy" => "#1f2a44",
    "blue" => "#2563eb", "red" => "#dc2626", "green" => "#16a34a", "yellow" => "#facc15",
    "beige" => "#e7d8c1", "pink" => "#ec4899"
  }.freeze

  has_many :print_areas, -> { order(:side) }, dependent: :destroy, inverse_of: :template
  has_many :template_sizes, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :template
  has_many :catalog_items, dependent: :restrict_with_error
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error

  accepts_nested_attributes_for :template_sizes, allow_destroy: true

  validates :kind, inclusion: { in: KINDS }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  # The column is NOT NULL and the field is optional, so an empty name is stored as "".
  normalizes :color_name, with: ->(value) { value.to_s.strip }, apply_to_nil: true
  validates :color_hex, format: { with: /\A#[0-9a-fA-F]{6}\z/ }
  validates :base_price_cents, :print_price_one_side_cents, :print_price_two_sides_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :name_present_in_default_locale

  slug_source :name

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  # The shop's own wording wins; otherwise the palette name in the current language.
  def color_label
    return color_name if color_name.present?
    key = PALETTE.key(color_hex.to_s.downcase)
    key ? I18n.t("colors.#{key}") : color_hex
  end

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
