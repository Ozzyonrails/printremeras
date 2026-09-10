module Rendering
  # Transparent PNG at 300 DPI sized to the physical print area (§17).
  class PrintFileRenderer < Renderer
    DPI = 300

    def render(print_area:, placements:)
      canvas_w = mm_to_px(print_area.width_mm)
      canvas_h = mm_to_px(print_area.height_mm)
      canvas = Vips::Image.black(canvas_w, canvas_h, bands: 4).copy(interpretation: :srgb)

      placements.each do |placement|
        art = prepare_artwork(placement, mm_to_px(placement.artwork_width_mm))
        left = (placement.x.to_f * canvas_w - art.width / 2.0).round
        top = (placement.y.to_f * canvas_h - art.height / 2.0).round
        canvas = canvas.composite2(art, :over, x: left, y: top)
      end

      file = Tempfile.new([ "print-#{print_area.side}", ".png" ])
      canvas.write_to_file(file.path, compression: 6)
      Output.new(file: file, content_type: "image/png", extension: "png")
    end

    private

    def mm_to_px(mm) = (mm.to_f * DPI / 25.4).round
  end
end
