module Rendering
  # Composites the product's artwork onto the garment photo. This is the picture customers
  # see in the catalogue; without it the shop can only show the bare garment.
  #
  # Runs inline from the admin (it takes well under a second) so a product always has its
  # picture, whether or not a background worker is running.
  class RenderCatalogPreview < ApplicationService
    def initialize(catalog_item:, renderer: Adapters.preview_renderer)
      @item = catalog_item
      @renderer = renderer
    end

    def call
      placements = @item.placements.includes(:design, :print_area).to_a
      return failure([ "no placements" ], code: :invalid) if placements.empty?

      area = placements.map(&:print_area).detect { |a| a.side == "front" } || placements.first.print_area
      return failure([ "no mockup" ], code: :invalid) unless area&.mockup&.attached?

      out = @renderer.render(print_area: area, placements: placements.select { |p| p.print_area_id == area.id })
      @item.preview.attach(io: File.open(out.file.path), filename: "#{@item.slug}-preview.#{out.extension}",
                           content_type: out.content_type)
      out.file.close!
      success(catalog_item: @item)
    end
  end
end
