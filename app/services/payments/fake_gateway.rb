module Payments
  # Development/test adapter: "checkout" is a local page (/dev/payments/:id) with buttons
  # that simulate approval, rejection and delayed confirmation by posting a webhook.
  # Simulated provider state is kept on the Payment's raw_payload (no external store).
  class FakeGateway < Gateway
    def provider = "fake"

    def create_checkout(order:, payment:, flow:, return_urls:)
      url = "#{Rails.configuration.x.app.public_url}/dev/payments/#{payment.id}"
      Checkout.new(preference_id: "fake-pref-#{payment.id}", checkout_url: url, qr_data: url, raw: { "fake" => true })
    end

    def fetch_payment(provider_payment_id)
      payment = Payment.find_by(provider: provider, provider_payment_id: provider_payment_id)
      state = payment&.raw_payload || {}
      PaymentInfo.new(provider_payment_id: provider_payment_id, status: state["simulated_status"] || "pending",
                      amount_cents: state["simulated_amount_cents"] || payment&.amount_cents, currency: state["simulated_currency"] || "ARS",
                      external_reference: payment&.external_reference, raw: state)
    end

    def parse_notification(params:, headers:, raw_body:)
      return nil if params["payment_id"].blank?
      Notification.new(event_id: params["event_id"].presence || "#{params['payment_id']}-#{params['status']}", event_type: "payment", payment_id: params["payment_id"], raw: params.to_h)
    end

    def refund(payment)
      PaymentInfo.new(provider_payment_id: payment.provider_payment_id, status: "refunded", amount_cents: payment.amount_cents, currency: "ARS", external_reference: payment.external_reference, raw: {})
    end

    # Used by the dev simulator page and tests: record the "provider" state, then send the webhook.
    def simulate!(payment:, status:, amount_cents: nil)
      provider_payment_id = payment.provider_payment_id.presence || "fake-#{payment.id}-#{SecureRandom.hex(3)}"
      payment.update!(provider_payment_id: provider_payment_id,
                      raw_payload: payment.raw_payload.merge("simulated_status" => status, "simulated_amount_cents" => amount_cents || payment.amount_cents))
      Payments::HandleWebhook.call(provider: "fake", params: { "payment_id" => provider_payment_id, "status" => status, "event_id" => "#{provider_payment_id}-#{status}-#{SecureRandom.hex(2)}" }, headers: {}, raw_body: "")
      provider_payment_id
    end
  end
end
