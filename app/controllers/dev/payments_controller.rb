module Dev
  # Fake gateway checkout page: simulate approve / reject / delayed confirmation.
  #
  # This page marks orders as paid without any money moving, so it must never be reachable
  # on a public deployment. The fake gateway alone is not a sufficient guard: someone could
  # select it in production by mistake. Production therefore requires an explicit
  # ALLOW_FAKE_PAYMENTS=true, meant for a private staging environment only.
  class PaymentsController < ApplicationController
    before_action { head :not_found unless simulator_available? }
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
  
    private

    def simulator_available?
      return false unless Adapters.payment_gateway.is_a?(Payments::FakeGateway)
      !Rails.env.production? || ENV["ALLOW_FAKE_PAYMENTS"] == "true"
    end
  end
end
