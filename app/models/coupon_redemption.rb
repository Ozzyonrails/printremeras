class CouponRedemption < ApplicationRecord
  belongs_to :coupon
  belongs_to :order
  belongs_to :user, optional: true

  scope :active, -> { where(restored_at: nil) }
end
