module Rendering
  # Storefront preview: mockup composited with the artwork at the placement coordinates,
  # JPEG ≈1200px on the long edge.
  class PreviewRenderer < Renderer
    MAX_EDGE = 1200

    def render(print_area:, placements:)
      mockup = print_area.mockup.blob.open { |f| Vips::Image.new_from_file(f.path, access: :sequential).copy_memory }
      mockup = mockup.autorot
      scale = [ MAX_EDGE.to_f / [ mockup.width, mockup.height ].max, 1.0 ].min
      mockup = mockup.resize(scale) if scale < 1
      mockup = mockup.colourspace(:srgb) if mockup.interpretation != :srgb
      mockup = mockup.bandjoin(255) unless mockup.has_alpha?

      area_left = print_area.x.to_f * mockup.width
      area_top = print_area.y.to_f * mockup.height
      area_w = print_area.w.to_f * mockup.width
      area_h = print_area.h.to_f * mockup.height

      placements.each do |placement|
        art = prepare_artwork(placement, (placement.scale.to_f * area_w).round)
        left = (area_left + placement.x.to_f * area_w - art.width / 2.0).round
        top = (area_top + placement.y.to_f * area_h - art.height / 2.0).round
        # Clip to the print area (overflow hidden, like the editor).
        art = clip(art, left, top, area_left, area_top, area_w, area_h)
        next unless art
        mockup = mockup.composite2(art[:image], :over, x: art[:x], y: art[:y])
      end

      file = Tempfile.new([ "preview-#{print_area.side}", ".jpg" ])
      mockup.flatten(background: [ 255, 255, 255 ]).write_to_file(file.path, Q: 85, strip: true)
      Output.new(file: file, content_type: "image/jpeg", extension: "jpg")
    end

    private

    def clip(art, left, top, area_left, area_top, area_w, area_h)
      x0 = [ left, area_left ].max
      y0 = [ top, area_top ].max
      x1 = [ left + art.width, area_left + area_w ].min
      y1 = [ top + art.height, area_top + area_h ].min
      return nil if x1 <= x0 || y1 <= y0
      cropped = art.crop((x0 - left).round, (y0 - top).round, (x1 - x0).round, (y1 - y0).round)
      { image: cropped, x: x0.round, y: y0.round }
    end
  end
end
