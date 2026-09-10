module Inventory
  class Adjust < ApplicationService
    def initialize(order:, direction:)
      @order = order
      @direction = direction
    end

    def call
      short = []
      TemplateSize.transaction do
        @order.items.includes(:template_size).each do |item|
          size = TemplateSize.lock.find(item.template_size_id)
          if @direction == :decrement
            if size.stock >= item.quantity
              size.update!(stock: size.stock - item.quantity)
            else
              short << "#{item.title} #{size.label}"
              size.update!(stock: 0)
            end
          else
            size.update!(stock: size.stock + item.quantity)
          end
        end
      end
      if short.any? && @direction == :decrement && !@order.problem?
        Orders::Transition.call(order: @order, to: "problem", reason: I18n.t("orders.problems.stock_short", items: short.join(", ")))
      end
      success(short: short)
    end
  end
end
