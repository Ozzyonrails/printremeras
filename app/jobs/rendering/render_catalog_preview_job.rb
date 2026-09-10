module Rendering
  class RenderCatalogPreviewJob < ApplicationJob
    queue_as :rendering
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(catalog_item_id)
      item = CatalogItem.find(catalog_item_id)
      placements = item.placements.includes(:design, :print_area)
      area = placements.map(&:print_area).detect { |a| a.side == "front" } || placements.first&.print_area
      return unless area&.mockup&.attached?
      out = Adapters.preview_renderer.render(print_area: area, placements: placements.select { |p| p.print_area_id == area.id })
      item.preview.attach(io: File.open(out.file.path), filename: "#{item.slug}-preview.#{out.extension}", content_type: out.content_type)
      out.file.close!
    end
  end
end
