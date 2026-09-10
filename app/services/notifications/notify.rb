module Notifications
  # Domain-event subscriber: translates an event payload into a Notifications::Deliver call.
  class Notify
    def self.call(event:, payload:)
      case event
      when :order_status_changed
        order = Order.find(payload[:order_id])
        # Specific events (approved/rejected/paid/cancelled/problem/refunded) have their own notice.
        return if Orders::Transition::EVENTS.key?(payload[:to].to_s)
        Notifications::Deliver.call(:order_status_changed, order: order, from: payload[:from], to: payload[:to])
      when :order_created, :order_approved, :order_rejected, :order_paid, :order_cancelled, :order_problem, :order_refunded
        Notifications::Deliver.call(event, order: Order.find(payload[:order_id]))
      when :payment_failed
        Notifications::Deliver.call(event, order: Order.find(payload[:order_id]))
      when :review_submitted, :review_approved, :review_rejected
        Notifications::Deliver.call(event, review: Review.find(payload[:review_id]))
      when :message_created
        Notifications::Deliver.call(event, message: Message.find(payload[:message_id]))
      end
    end
  end
end
