module Api
  module V1
    class CouponsController < BaseController
      def validate
        subtotal = Orders::Pricing.subtotal_cents(current_cart.items.includes(:template, :catalog_item, :placements))
        result = Coupons::Validate.call(code: params.require(:code), user: current_user, subtotal_cents: subtotal)
        render_result(result) { |r| render json: { coupon: Serializers.coupon(r.coupon), discount_cents: r.discount_cents } }
      end

      # Coupons the customer owns and can still use (auto-suggested at checkout).
      def mine
        return render json: { coupons: [] } unless signed_in?
        coupons = current_user.coupons.active.select(&:currently_valid?)
        render json: { coupons: coupons.map { |c| Serializers.coupon(c) } }
      end
    end
  end
end
