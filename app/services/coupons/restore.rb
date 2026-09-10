module Coupons
  # Cancelling an order gives the coupon back.
  class Restore < ApplicationService
    def initialize(order:)
      @order = order
    end

    def call
      redemption = @order.coupon_redemption
      return success(restored: false) if redemption.nil? || redemption.restored_at.present?

      Coupon.transaction do
        coupon = Coupon.lock.find(redemption.coupon_id)
        coupon.update!(used_count: [ coupon.used_count - 1, 0 ].max)
        redemption.update!(restored_at: Time.current)
      end
      success(restored: true)
    end
  end
end
