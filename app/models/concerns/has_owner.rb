# Objects owned by either a User or a GuestSession (designs, carts).
module HasOwner
  extend ActiveSupport::Concern

  included do
    belongs_to :owner, polymorphic: true, optional: true
    scope :owned_by, ->(owner) { where(owner: owner) }
  end
end
