module Orders
  class Cancel < ApplicationService
    def initialize(order:, actor:, reason: nil)
      @order = order
      @actor = actor
      @reason = reason
    end

    def call
      if @actor.is_a?(User)
        return failure([ I18n.t("orders.errors.not_yours") ], code: :forbidden) unless @order.user_id == @actor.id
        return failure([ I18n.t("orders.errors.cannot_cancel") ], code: :invalid) unless @order.customer_can_cancel?
      end
      Orders::Transition.call(order: @order, to: "cancelled", actor: @actor, reason: @reason)
    end
  end
end
