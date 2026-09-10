module Orders
  # Subscriber to order_paid. Row-locks each size so concurrent orders can never drive
  # stock negative; if stock is short the order is flagged as a problem for staff.
  class DecrementInventory
    def self.call(event:, payload:)
      order = Order.find(payload[:order_id])
      Inventory::Adjust.call(order: order, direction: :decrement)
    end
  end
end
