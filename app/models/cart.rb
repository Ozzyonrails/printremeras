class Cart < ApplicationRecord
  include HasOwner
  has_many :items, class_name: "CartItem", dependent: :destroy, inverse_of: :cart

  validates :owner, presence: true

  def empty? = items.none?
  def total_quantity = items.sum(:quantity)
end
