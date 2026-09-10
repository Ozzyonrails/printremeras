module Api
  module V1
    class CartController < BaseController
      def show
        render json: { cart: Serializers.cart(current_cart) }
      end

      def add_item
        result = Orders::AddToCart.call(cart: current_cart, owner: current_owner, template_id: params.require(:template_id), template_size_id: params.require(:template_size_id),
                                        quantity: params.fetch(:quantity, 1), catalog_item_id: params[:catalog_item_id], placements: params[:placements].to_a.map(&:to_unsafe_h))
        render_result(result) { render json: { cart: Serializers.cart(current_cart.reload) }, status: :created }
      end

      def update_item
        item = current_cart.items.find(params[:id])
        result = Orders::UpdateCartItem.call(cart_item: item, owner: current_owner, quantity: params[:quantity], template_size_id: params[:template_size_id],
                                             placements: params[:placements]&.map(&:to_unsafe_h))
        render_result(result) { render json: { cart: Serializers.cart(current_cart.reload) } }
      end

      def remove_item
        current_cart.items.find(params[:id]).destroy!
        render json: { cart: Serializers.cart(current_cart.reload) }
      end

      # POST /api/v1/cart/quote — totals preview for the checkout page
      def quote
        address = signed_in? && params[:address_id].present? ? current_user.addresses.find_by(id: params[:address_id]) : nil
        result = Orders::Quote.call(cart: current_cart, user: current_user, shipping_method: params[:shipping_method], address: address, coupon_code: params[:coupon_code], rush: params[:rush])
        render_result(result) { |q| render json: { quote: Serializers.quote(q) } }
      end
    end
  end
end
