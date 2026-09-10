module Orders
  # Artwork moderation (§13): approve moves to awaiting_payment, reject ends the order.
  class Approve < ApplicationService
    def initialize(order:, admin_user:)
      @order = order
      @admin = admin_user
    end

    def call
      AuditLog.record!(action: "order.artwork_approved", admin_user: @admin, subject: @order)
      @order.placements.each { |p| p.design.update_columns(moderation_status: "approved") if p.design.moderation_status == "pending" }
      Orders::Transition.call(order: @order, to: "awaiting_payment", actor: @admin)
    end
  end
end
