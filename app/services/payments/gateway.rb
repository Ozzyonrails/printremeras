module Payments
  # Port for payment providers. Vendor SDKs/HTTP calls live only inside adapters.
  class Gateway
    Checkout = Struct.new(:preference_id, :checkout_url, :qr_data, :raw, keyword_init: true)
    PaymentInfo = Struct.new(:provider_payment_id, :status, :amount_cents, :currency, :external_reference, :raw, keyword_init: true)
    Notification = Struct.new(:event_id, :event_type, :payment_id, :raw, keyword_init: true)

    class Error < StandardError; end

    def provider = raise(NotImplementedError)
    def configured? = true

    # Create a checkout for an order. flow is :redirect or :qr. Returns Checkout.
    def create_checkout(order:, payment:, flow:, return_urls:) = raise(NotImplementedError)

    # Fetch the authoritative payment status from the provider. Returns PaymentInfo.
    def fetch_payment(provider_payment_id) = raise(NotImplementedError)

    # Parse an inbound webhook request into a Notification (or nil to ignore).
    def parse_notification(params:, headers:, raw_body:) = raise(NotImplementedError)

    # Refund an approved payment. Returns PaymentInfo.
    def refund(payment) = raise(NotImplementedError)
  end
end
