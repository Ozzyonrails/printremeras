module Orders
  class UpdateCartItem < ApplicationService
    def initialize(cart_item:, owner:, quantity: nil, template_size_id: nil, placements: nil)
      @item = cart_item
      @owner = owner
      @quantity = quantity
      @size_id = template_size_id
      @placements = placements
    end

    def call
      ActiveRecord::Base.transaction do
        if @size_id.present?
          size = @item.template.template_sizes.find_by(id: @size_id)
          return failure([ I18n.t("cart.errors.no_size") ]) unless size
          @item.template_size = size
        end
        @item.quantity = @quantity.to_i.clamp(1, 100) if @quantity.present?
        if @placements && @item.custom?
          built = Catalog::BuildPlacements.call(template: @item.template, placements: @placements, owner: @owner, placeable: @item)
          return failure(built.errors) if built.failure?
          @item.placements.destroy_all
          built.placements.each { |p| p.placeable = @item; p.save! }
        end
        return failure(@item.errors.full_messages) unless @item.save
      end
      success(cart_item: @item.reload)
    end
  end
end
