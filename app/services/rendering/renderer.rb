module Rendering
  # Port for output renderers. Implementations receive the print area, the placements
  # for that side and return a Tempfile plus a content type. Different formats (PDF,
  # TIFF, RIP layouts) are added as new adapters registered in config.x.rendering.
  class Renderer
    Output = Struct.new(:file, :content_type, :extension, keyword_init: true)

    def render(print_area:, placements:) = raise(NotImplementedError)

    private

    # Uses the upscaled file when one exists, otherwise the original upload.
    def load_design(design)
      design.print_ready_file.blob.open { |f| Vips::Image.new_from_file(f.path, access: :sequential).copy_memory }
    end

    # Artwork scaled to a target width (px), rotated, with alpha preserved.
    def prepare_artwork(placement, target_width_px)
      image = load_design(placement.design)
      image = image.autorot if image.respond_to?(:autorot)
      image = image.colourspace(:srgb) if image.interpretation != :srgb
      image = image.bandjoin(255) unless image.has_alpha?
      factor = target_width_px.to_f / image.width
      image = image.resize(factor, kernel: :lanczos3) if (factor - 1).abs > 0.001
      image = image.rotate(placement.rotation.to_f, background: [ 0, 0, 0, 0 ]) if placement.rotation.to_f.abs > 0.01
      image
    end
  end
end
