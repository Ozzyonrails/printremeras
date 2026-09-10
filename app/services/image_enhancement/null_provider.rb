module ImageEnhancement
  # Default: no upscaling service wired up. Low-resolution artwork is still detected and
  # marked, so the queue is ready the day a paid provider is configured.
  class NullProvider < Provider
    def name = :none
    def available? = false

    def enhance(design:, target_width_px:, target_height_px:)
      raise Unavailable, I18n.t("designs.enhancement.no_provider")
    end
  end
end
