module Orders
  class Reject < ApplicationService
    def initialize(order:, admin_user:, reason:)
      @order = order
      @admin = admin_user
      @reason = reason
    end

    def call
      return failure([ I18n.t("orders.errors.reason_required") ]) if @reason.blank?
      AuditLog.record!(action: "order.artwork_rejected", admin_user: @admin, subject: @order, change_set: { "reason" => @reason })
      @order.placements.each { |p| p.design.update_columns(moderation_status: "rejected") if p.design.moderation_status == "pending" }
      result = Orders::Transition.call(order: @order, to: "rejected", actor: @admin, reason: @reason)
      Coupons::Restore.call(order: @order) if result.success?
      result
    end
  end
end
