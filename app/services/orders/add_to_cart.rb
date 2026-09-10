module Orders
  class AddToCart < ApplicationService
    def initialize(cart:, owner:, template_id:, template_size_id:, quantity: 1, catalog_item_id: nil, placements: [])
      @cart = cart
      @owner = owner
      @template_id = template_id
      @size_id = template_size_id
      @quantity = quantity.to_i.clamp(1, 100)
      @catalog_item_id = catalog_item_id
      @placements = placements
    end

    def call
      template = Template.active.find_by(id: @template_id)
      return failure([ I18n.t("cart.errors.unknown_template") ], code: :not_found) unless template
      size = template.template_sizes.find_by(id: @size_id)
      return failure([ I18n.t("cart.errors.no_size") ], code: :invalid) unless size
      return failure([ I18n.t("cart.errors.out_of_stock", item: template.name, size: size.label) ], code: :invalid) if size.stock < @quantity

      catalog_item = nil
      built = nil
      if @catalog_item_id.present?
        catalog_item = CatalogItem.published.find_by(id: @catalog_item_id, template_id: template.id)
        return failure([ I18n.t("cart.errors.unknown_product") ], code: :not_found) unless catalog_item
      else
        built = Catalog::BuildPlacements.call(template: template, placements: @placements, owner: @owner)
        return failure(built.errors, code: :invalid) if built.failure?
      end

      cart_item = nil
      ActiveRecord::Base.transaction do
        cart_item = @cart.items.create!(template: template, template_size: size, catalog_item: catalog_item, quantity: @quantity)
        built&.placements&.each { |p| p.placeable = cart_item; p.save! }
        merge_duplicates(cart_item)
      end
      success(cart_item: cart_item.reload)
    end

    private

    def merge_duplicates(new_item)
      key = new_item.merge_key
      @cart.items.where.not(id: new_item.id).includes(:placements).each do |other|
        next unless other.merge_key == key
        new_item.update!(quantity: new_item.quantity + other.quantity)
        other.destroy!
      end
    end
  end
end
