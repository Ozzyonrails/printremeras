module Catalog
  # "Customise this design": copies the product's placements into a new cart item so the
  # customer can edit it. From then on it is priced as a regular custom order.
  class CustomizeFromCatalog < ApplicationService
    def initialize(catalog_item:, cart:, template_size_id:, owner:)
      @item = catalog_item
      @cart = cart
      @size_id = template_size_id
      @owner = owner
    end

    def call
      size = @item.template.template_sizes.find_by(id: @size_id) || @item.template.template_sizes.find_by(stock: 1..) || @item.template.template_sizes.first
      return failure([ I18n.t("cart.errors.no_size") ]) unless size

      cart_item = nil
      ActiveRecord::Base.transaction do
        cart_item = @cart.items.create!(template: @item.template, template_size: size, catalog_item: nil, quantity: 1)
        @item.placements.each do |p|
          cart_item.placements.create!(design: p.design, print_area: p.print_area, x: p.x, y: p.y, scale: p.scale, rotation: p.rotation)
        end
      end
      success(cart_item: cart_item)
    end
  end
end
