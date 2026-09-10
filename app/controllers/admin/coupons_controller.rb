module Admin
  class CouponsController < BaseController
    before_action :require_admin_role!

    def index
      @coupons = paginate(Coupon.includes(:owner).order(created_at: :desc))
      @stats = { issued: Coupon.count, redeemed: CouponRedemption.active.count, discount_total: CouponRedemption.active.sum(:discount_cents) }
    end

    def new
      @coupon = Coupon.new(discount_type: "percentage", source: "manual", valid_until: 90.days.from_now)
    end

    def create
      attrs = params.require(:coupon).permit(:code, :discount_type, :discount_value, :source, :max_uses, :min_order_cents, :valid_from, :valid_until, :active, :note).to_h
      attrs[:owner] = User.find_by(email: params[:owner_email].to_s.downcase.strip) if params[:owner_email].present?
      return redirect_to(new_admin_coupon_path, alert: t("admin.coupons.owner_not_found")) if params[:owner_email].present? && attrs[:owner].nil?
      result = Coupons::Issue.call(attributes: attrs, admin_user: current_admin)
      if result.success?
        redirect_to admin_coupons_path, notice: t("admin.coupons.created", code: result.coupon.code)
      else
        @coupon = Coupon.new(attrs.except(:owner))
        flash.now[:alert] = result.error_message
        render :new, status: :unprocessable_content
      end
    end

    def update
      coupon = Coupon.find(params[:id])
      coupon.update!(active: params[:active] == "1")
      audit!("coupon.active_changed", coupon, { "active" => coupon.active })
      redirect_to admin_coupons_path, notice: t("admin.saved")
    end
  end
end
