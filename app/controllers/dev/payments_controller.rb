module Dev
  # Fake gateway checkout page: simulate approve / reject / delayed confirmation.
  class PaymentsController < ApplicationController
    before_action { head :not_found unless Adapters.payment_gateway.is_a?(Payments::FakeGateway) }
    layout "admin"

    def show
      @payment = Payment.find(params[:id])
      @order = @payment.order
    end

    def simulate
      payment = Payment.find(params[:id])
      gateway = Adapters.payment_gateway
      status = %w[approved rejected pending].include?(params[:status]) ? params[:status] : "approved"
      if params[:delay].present?
        Dev::DelayedSimulationJob.set(wait: params[:delay].to_i.seconds).perform_later(payment.id, status)
        flash[:notice] = "Confirmation will arrive in #{params[:delay]}s"
      else
        gateway.simulate!(payment: payment, status: status, amount_cents: params[:amount_cents].presence&.to_i)
        flash[:notice] = "Webhook sent: #{status}"
      end
      redirect_to dev_payment_path(payment)
    end
  end
end
