class CartItem < ApplicationRecord
  belongs_to :cart, inverse_of: :items
  belongs_to :template
  belongs_to :template_size
  belongs_to :catalog_item, optional: true
  has_many :placements, as: :placeable, dependent: :destroy

  validates :quantity, numericality: { greater_than_or_equal_to: 1, only_integer: true }
  validate :size_belongs_to_template

  def sides_count = placements.map(&:print_area_id).uniq.size
  def custom? = catalog_item_id.nil?

  # Two cart items are "identical" (and merged) when they share product, size and placements.
  def merge_key
    [ template_id, template_size_id, catalog_item_id, placements.map { |p| [ p.design_id, p.print_area_id, p.x.to_f.round(4), p.y.to_f.round(4), p.scale.to_f.round(4), p.rotation.to_f.round(2) ] }.sort ]
  end

  private

  def size_belongs_to_template
    errors.add(:template_size, :invalid) if template_size && template && template_size.template_id != template_id
  end
end
