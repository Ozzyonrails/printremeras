module Payments
  # Creates a Payment for an order awaiting payment and asks the gateway for a checkout.
  class StartCheckout < ApplicationService
    def initialize(order:, flow: "redirect", gateway: Adapters.payment_gateway)
      @order = order
      @flow = Payment::FLOWS.include?(flow.to_s) ? flow.to_s : "redirect"
      @gateway = gateway
    end

    def call
      return failure([ I18n.t("payments.errors.not_payable") ], code: :invalid) unless @order.awaiting_payment?
      return failure([ I18n.t("payments.errors.not_configured") ], code: :unavailable) unless @gateway.configured?

      payment = @order.payments.create!(provider: @gateway.provider, flow: @flow, amount_cents: @order.total_cents, currency: @order.currency,
                                        external_reference: "#{@order.number}-#{SecureRandom.hex(3)}")
      checkout = @gateway.create_checkout(order: @order, payment: payment, flow: @flow, return_urls: return_urls)
      payment.update!(provider_preference_id: checkout.preference_id, checkout_url: checkout.checkout_url, qr_data: checkout.qr_data, raw_payload: checkout.raw || {})
      success(payment: payment)
    rescue Payments::Gateway::Error => e
      Rails.logger.error("[payments] #{e.message}")
      failure([ I18n.t("payments.errors.gateway", message: e.message) ], code: :gateway_error)
    end

    private

    def return_urls
      base = Rails.configuration.x.app.public_url
      {
        success: "#{base}/orders/#{@order.number}?payment=success",
        failure: "#{base}/orders/#{@order.number}?payment=failure",
        pending: "#{base}/orders/#{@order.number}?payment=pending",
        webhook: "#{base}/webhooks/#{@gateway.provider}"
      }
    end
  end
end
