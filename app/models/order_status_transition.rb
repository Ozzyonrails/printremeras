class OrderStatusTransition < ApplicationRecord
  belongs_to :order
  belongs_to :actor, polymorphic: true, optional: true
  default_scope { order(:created_at, :id) }
end
