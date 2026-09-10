module Rendering
  class RenderOrderItemJob < ApplicationJob
    queue_as :rendering
    retry_on StandardError, wait: :polynomially_longer, attempts: 4

    def perform(order_item_id)
      item = OrderItem.find(order_item_id)
      Rendering::RenderOrderItem.call(order_item: item)
    end
  end
end
