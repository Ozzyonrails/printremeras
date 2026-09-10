class TemplateSize < ApplicationRecord
  belongs_to :template, inverse_of: :template_sizes
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error

  validates :label, presence: true, uniqueness: { scope: :template_id }
  validates :stock, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  def available? = stock.positive?
  def out_of_stock? = !available?
end
