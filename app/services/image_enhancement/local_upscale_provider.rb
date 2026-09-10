module ImageEnhancement
  # Stop-gap provider: a plain libvips resize. It adds no detail, so it is not a
  # substitute for a real upscaler, but it lets the whole flow be exercised (and gives
  # the printer a file at the right pixel size). Enable with
  # IMAGE_ENHANCEMENT_PROVIDER=ImageEnhancement::LocalUpscaleProvider.
  class LocalUpscaleProvider < Provider
    MAX_FACTOR = 4.0

    def name = :local_upscale
    def available? = true

    def enhance(design:, target_width_px:, target_height_px:)
      require "vips"
      file = Tempfile.new([ "enhanced", ".png" ])
      design.file.blob.open do |source|
        image = Vips::Image.new_from_file(source.path, access: :sequential)
        factor = [ target_width_px.to_f / image.width, MAX_FACTOR ].min
        image = image.resize(factor, kernel: :lanczos3) if factor > 1
        image.write_to_file(file.path)
        @result = Result.new(io: File.open(file.path), width_px: image.width, height_px: image.height,
                             content_type: "image/png", provider_reference: "local-#{design.id}")
      end
      @result
    rescue Vips::Error => e
      raise Error, e.message
    end
  end
end
