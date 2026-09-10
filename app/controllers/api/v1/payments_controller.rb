module Api
  module V1
    class PaymentsController < BaseController
      before_action :require_user!

      # POST /api/v1/orders/:number/payments { flow: redirect|qr }
      def create
        order = current_user.orders.find_by!(number: params[:number])
        pending = order.payments.where(status: "pending", flow: params[:flow].presence || "redirect").where(created_at: 20.hours.ago..).order(created_at: :desc).first
        return render json: { payment: Serializers.payment(pending) } if pending && order.awaiting_payment?

        result = Payments::StartCheckout.call(order: order, flow: params[:flow].presence || "redirect")
        render_result(result) { |r| render json: { payment: Serializers.payment(r.payment) }, status: :created }
      end

      # GET /api/v1/orders/:number/payments/status — polled by the QR screen
      def status
        order = current_user.orders.find_by!(number: params[:number])
        render json: { order_status: order.status, payment_status: order.latest_payment&.status }
      end
    end
  end
end
