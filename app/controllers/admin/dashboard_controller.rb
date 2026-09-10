module Admin
  class DashboardController < BaseController
    def index
      @counts = {
        pending_approval: Order.where(status: "pending_approval").count,
        awaiting_payment: Order.where(status: "awaiting_payment").count,
        paid: Order.where(status: "paid").count,
        in_production: Order.where(status: %w[preparing in_production]).count,
        to_ship: Order.where(status: %w[awaiting_courier ready_for_pickup in_transit]).count,
        problem: Order.where(status: "problem").count,
        pending_reviews: Review.pending.count,
        artwork_to_enhance: Design.needing_enhancement.count,
        unread_conversations: Conversation.with_unread_for_admin.count,
        low_stock: TemplateSize.where(stock: ..2).joins(:template).where(templates: { active: true }).count
      }
      @recent_orders = Order.placed.recent.includes(:user).limit(10)
      @revenue_30d = Order.where(paid_at: 30.days.ago..).where.not(status: %w[refunded cancelled]).sum(:total_cents)
    end
  end
end
