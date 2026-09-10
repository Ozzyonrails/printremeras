module Coupons
  # Creates a coupon (manual, campaign or review reward) and publishes coupon_issued.
  class Issue < ApplicationService
    def initialize(attributes:, admin_user: nil)
      @attributes = attributes
      @admin = admin_user
    end

    def call
      coupon = Coupon.new(@attributes)
      coupon.code = Coupon.generate_code(coupon.source == "review_reward" ? "GRACIAS" : "PR") if coupon.code.blank?
      return failure(coupon.errors.full_messages) unless coupon.save

      AuditLog.record!(action: "coupon.issued", admin_user: @admin, subject: coupon, change_set: coupon.attributes.slice("code", "discount_type", "discount_value", "owner_id", "source", "max_uses", "valid_until"))
      DomainEvents.publish(:coupon_issued, coupon_id: coupon.id)
      success(coupon: coupon)
    end
  end
end
