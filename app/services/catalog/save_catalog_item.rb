module Catalog
  # Admin builds a product in the same editor; placements are replaced atomically.
  class SaveCatalogItem < ApplicationService
    def initialize(catalog_item:, attributes:, placements:, admin_user:)
      @item = catalog_item
      @attributes = attributes
      @placements = placements
      @admin = admin_user
    end

    def call
      @item.assign_attributes(@attributes)
      built = @placements.nil? ? nil : Catalog::BuildPlacements.call(template: @item.template, placements: @placements, owner: @admin, placeable: @item)
      return failure(built.errors) if built&.failure?

      ActiveRecord::Base.transaction do
        return failure(@item.errors.full_messages) unless @item.save
        if built
          @item.placements.destroy_all
          built.placements.each { |p| p.placeable = @item; p.save! }
        end
      end
      AuditLog.record!(action: "catalog_item.saved", admin_user: @admin, subject: @item, change_set: @item.saved_changes.except("updated_at"))
      Rendering::RenderCatalogPreview.call(catalog_item: @item.reload) if built
      success(catalog_item: @item)
    end
  end
end
