module ImageEnhancement
  # Port for artwork upscaling / restoration providers (a paid AI service, or an
  # in-house model). Registered in config.x.image_enhancement.provider and resolved
  # through Adapters.image_enhancement_provider, so no call site names a vendor.
  class Provider
    # io must be a rewound IO of the improved image.
    Result = Struct.new(:io, :width_px, :height_px, :content_type, :provider_reference, keyword_init: true)

    class Unavailable < StandardError; end
    class Error < StandardError; end

    def name = raise(NotImplementedError)

    # False when the provider has no credentials configured; callers then only mark
    # the design and leave the actual upscaling for later.
    def available? = false

    # design: the Design to improve. target_*_px: the size needed to reach the
    # required DPI at the largest placement. Returns a Result.
    def enhance(design:, target_width_px:, target_height_px:) = raise(NotImplementedError)
  end
end
