module Coupons
  # Records a redemption against an order and bumps the counter under a row lock.
  class Redeem < ApplicationService
    def initialize(coupon:, order:, discount_cents:)
      @coupon = coupon
      @order = order
      @discount = discount_cents
    end

    def call
      redemption = nil
      Coupon.transaction do
        coupon = Coupon.lock.find(@coupon.id)
        return failure([ I18n.t("coupons.errors.exhausted") ], code: :exhausted) if coupon.exhausted?
        coupon.increment!(:used_count)
        redemption = CouponRedemption.create!(coupon: coupon, order: @order, user: @order.user, discount_cents: @discount)
        @order.update_columns(coupon_id: coupon.id, coupon_code: coupon.code)
      end
      success(redemption: redemption)
    end
  end
end
