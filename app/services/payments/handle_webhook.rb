module Payments
  # Step 1 of webhook handling: record the event idempotently and enqueue processing.
  # The controller responds 200 immediately; nothing here talks to the provider.
  class HandleWebhook < ApplicationService
    def initialize(provider:, params:, headers:, raw_body:, gateway: Adapters.payment_gateway)
      @provider = provider.to_s
      @params = params
      @headers = headers
      @raw_body = raw_body
      @gateway = gateway
    end

    def call
      return failure([ "unknown provider" ], code: :not_found) unless @gateway.provider == @provider
      notification = @gateway.parse_notification(params: @params, headers: @headers, raw_body: @raw_body)
      return success(ignored: true) if notification.nil?

      event = PaymentEvent.create!(provider: @provider, provider_event_id: notification.event_id, event_type: notification.event_type,
                                   payload: { "payment_id" => notification.payment_id, "raw" => notification.raw })
      Payments::ProcessEventJob.perform_later(event.id)
      success(event: event)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      success(duplicate: true)
    rescue Payments::Gateway::Error => e
      failure([ e.message ], code: :unauthorized)
    end
  end
end
