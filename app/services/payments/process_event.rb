module Payments
  # Step 2: fetch the authoritative status from the provider (never trust the webhook
  # body), verify amount + external_reference, and transition the order.
  class ProcessEvent < ApplicationService
    def initialize(payment_event:, gateway: Adapters.payment_gateway)
      @event = payment_event
      @gateway = gateway
    end

    def call
      return success(skipped: :already_processed) if @event.processed?

      info = @gateway.fetch_payment(@event.payload["payment_id"])
      payment = Payment.find_by(external_reference: info.external_reference.to_s)
      return finish("unmatched_reference") unless payment

      order = payment.order
      @event.update!(order: order)
      payment.update!(provider_payment_id: info.provider_payment_id, raw_payload: info.raw || {})

      case info.status
      when "approved"
        unless info.amount_cents.to_i == payment.amount_cents && info.currency.to_s.upcase == payment.currency.upcase
          payment.update!(status: "rejected")
          Orders::Transition.call(order: order, to: "problem", reason: I18n.t("orders.problems.amount_mismatch", expected: payment.amount_cents, got: info.amount_cents)) if order.awaiting_payment?
          return finish("amount_mismatch")
        end
        Payment.transaction do
          payment.update!(status: "approved", approved_at: Time.current)
          if order.awaiting_payment?
            result = Orders::Transition.call(order: order, to: "paid")
            raise ActiveRecord::Rollback if result.failure?
          end
        end
        finish("approved")
      when "rejected", "cancelled"
        payment.update!(status: info.status)
        DomainEvents.publish(:payment_failed, order_id: order.id, payment_id: payment.id)
        finish(info.status)
      when "refunded"
        payment.update!(status: "refunded")
        finish("refunded")
      else
        payment.update!(status: "pending")
        finish("pending")
      end
    end

    private

    def finish(result)
      @event.update!(processed_at: Time.current, result: result)
      success(result: result)
    end
  end
end
