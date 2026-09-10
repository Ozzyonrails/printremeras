module Catalog
  # Takes an uploaded artwork file and puts it on the product's front print area, centred
  # and scaled to fit. The admin then nudges it in the editor; this exists so creating a
  # product is one step rather than "save, then go find the upload button".
  class AddDesignToProduct < ApplicationService
    def initialize(catalog_item:, file:, admin_user: nil)
      @item = catalog_item
      @file = file
      @admin = admin_user
    end

    def call
      return failure([ I18n.t("admin.catalog.design_required") ], code: :invalid) if @file.blank?
      return failure([ I18n.t("admin.templates.mockup_not_a_file") ], code: :invalid) unless @file.respond_to?(:tempfile)

      area = @item.template.front_area || @item.template.print_areas.first
      return failure([ I18n.t("admin.catalog.template_without_area") ], code: :invalid) if area.nil?

      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(@file.tempfile.path), filename: @file.original_filename,
        content_type: @file.content_type, service_name: ApplicationRecord.private_storage.to_s
      )
      created = Catalog::CreateDesign.call(owner: nil, signed_blob_id: blob.signed_id, source: "catalog")
      return failure(created.errors, code: created.code) if created.failure?

      design = created.design
      design.update_columns(moderation_status: "approved")
      placement = @item.placements.create(design: design, print_area: area, x: 0.5, y: 0.5,
                                          scale: fitting_scale(design, area), rotation: 0)
      return failure(placement.errors.full_messages, code: :invalid) unless placement.persisted?

      AuditLog.record!(action: "catalog_item.design_added", admin_user: @admin, subject: @item,
                       change_set: { "design_id" => design.id, "side" => area.side })
      Rendering::RenderCatalogPreviewJob.perform_later(@item.id)
      success(design: design, placement: placement)
    end

    private

    # Centred at 60% of the area's width, pulled in further when the artwork is tall enough
    # that 60% would overflow the area's height.
    def fitting_scale(design, area)
      ratio = design.effective_height_px.to_f / design.effective_width_px.to_f
      max_for_height = area.height_mm.to_f / (area.width_mm.to_f * ratio)
      [ 0.6, max_for_height * 0.9, Placement::MAX_SCALE ].min.round(4)
    end
  end
end
