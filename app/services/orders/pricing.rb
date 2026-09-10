module Orders
  # Pure pricing rules (§9). Used for cart display, checkout quotes and order creation.
  module Pricing
    module_function

    def unit_price_cents(template:, catalog_item:, sides_count:)
      return catalog_item.price_cents if catalog_item
      template.base_price_cents + template.print_price_for(sides_count)
    end

    def line_for(item)
      sides = item.sides_count
      unit = unit_price_cents(template: item.template, catalog_item: item.catalog_item, sides_count: sides)
      { sides_count: sides, unit_price_cents: unit, line_total_cents: unit * item.quantity }
    end

    def subtotal_cents(items)
      items.sum { |i| line_for(i)[:line_total_cents] }
    end
  end
end
