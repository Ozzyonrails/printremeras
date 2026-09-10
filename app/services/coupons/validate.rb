module Coupons
  # The only place coupon eligibility is decided.
  class Validate < ApplicationService
    def initialize(code:, user:, subtotal_cents:)
      @code = code.to_s.strip.upcase
      @user = user
      @subtotal = subtotal_cents.to_i
    end

    def call
      return failure([ I18n.t("coupons.errors.blank") ], code: :blank) if @code.blank?
      coupon = Coupon.find_by(code: @code)
      return failure([ I18n.t("coupons.errors.not_found") ], code: :not_found) unless coupon
      return failure([ I18n.t("coupons.errors.inactive") ], code: :inactive) unless coupon.active?
      return failure([ I18n.t("coupons.errors.not_started") ], code: :not_started) unless coupon.started?
      return failure([ I18n.t("coupons.errors.expired") ], code: :expired) if coupon.expired?
      return failure([ I18n.t("coupons.errors.exhausted") ], code: :exhausted) if coupon.exhausted?
      return failure([ I18n.t("coupons.errors.not_yours") ], code: :not_owner) if coupon.personal? && coupon.owner_id != @user&.id
      if coupon.min_order_cents.present? && @subtotal < coupon.min_order_cents
        return failure([ I18n.t("coupons.errors.min_order", amount: Money.format(coupon.min_order_cents)) ], code: :min_order)
      end

      success(coupon: coupon, discount_cents: coupon.discount_for(@subtotal))
    end
  end
end
