module Orders
  # Subscriber to order_cancelled / order_refunded: put stock back if it had been taken.
  class RestoreInventory
    def self.call(event:, payload:)
      order = Order.find(payload[:order_id])
      Coupons::Restore.call(order: order)
      return unless Order::STOCK_HOLDING.include?(payload[:from].to_s)
      Inventory::Adjust.call(order: order, direction: :increment)
    end
  end
end
