module Rendering
  # Subscriber to order_paid: one job per order item renders previews + print files.
  class GeneratePrintFiles
    def self.call(event:, payload:)
      order = Order.find(payload[:order_id])
      order.items.each { |item| Rendering::RenderOrderItemJob.perform_later(item.id) }
    end
  end
end
