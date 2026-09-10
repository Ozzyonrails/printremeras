module Api
  module V1
    class OrdersController < BaseController
      before_action :require_user!

      def index
        orders = current_user.orders.placed.recent.includes(:review, items: [ :template, :catalog_item, preview_attachment: :blob ])
        render json: { orders: orders.map { |o| Serializers.order(o) } }
      end

      def show
        order = current_user.orders.includes(items: [ :template, :catalog_item, placements: [ :design, :print_area ] ]).find_by!(number: params[:number])
        render json: { order: Serializers.order(order, full: true) }
      end

      # POST /api/v1/orders — "Place order". Login is requested at this moment, never earlier.
      def create
        address = params[:address_id].present? ? current_user.addresses.find_by(id: params[:address_id]) : nil
        if address.nil? && params[:address].present?
          address = current_user.addresses.build(address_params.merge(is_default: current_user.addresses.none?))
          return render_errors(address.errors.full_messages) unless address.save
        end
        result = Orders::Create.call(user: current_user, cart: current_cart, shipping_method: params.require(:shipping_method), address: address,
                                     coupon_code: params[:coupon_code], rush: params[:rush], customer_notes: params[:customer_notes], locale: I18n.locale.to_s)
        render_result(result) { |r| render json: { order: Serializers.order(r.order, full: true) }, status: :created }
      end

      def cancel
        order = current_user.orders.find_by!(number: params[:number])
        result = Orders::Cancel.call(order: order, actor: current_user, reason: params[:reason])
        render_result(result) { |r| render json: { order: Serializers.order(r.order.reload, full: true) } }
      end

      private

      def address_params
        params.require(:address).permit(:recipient_name, :phone, :street, :number, :apartment, :floor, :neighborhood, :postal_code, :city, :notes)
      end
    end
  end
end
