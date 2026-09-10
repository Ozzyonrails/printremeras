module Payments
  # Operator-triggered refund for defects (§13). Moves the order to refunded.
  class Refund < ApplicationService
    def initialize(order:, admin_user:, reason:, gateway: Adapters.payment_gateway)
      @order = order
      @admin = admin_user
      @reason = reason
      @gateway = gateway
    end

    def call
      payment = @order.payments.approved.first
      return failure([ I18n.t("payments.errors.nothing_to_refund") ]) unless payment
      return failure([ I18n.t("orders.errors.invalid_transition", from: @order.status, to: "refunded") ]) unless Orders::Transition.allowed?(@order.status, "refunded")

      info = @gateway.refund(payment)
      payment.update!(status: "refunded", raw_payload: payment.raw_payload.merge("refund" => info.raw))
      AuditLog.record!(action: "order.refunded", admin_user: @admin, subject: @order, change_set: { "amount_cents" => payment.amount_cents, "reason" => @reason })
      Orders::Transition.call(order: @order, to: "refunded", actor: @admin, reason: @reason)
    rescue Payments::Gateway::Error => e
      failure([ e.message ], code: :gateway_error)
    end
  end
end
