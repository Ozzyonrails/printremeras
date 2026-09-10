module Designs
  # Runs the configured provider and stores the improved file alongside the original.
  # The original is never replaced, so an operator can always compare or revert.
  class Enhance < ApplicationService
    def initialize(design:, target_width_px:, target_height_px:, provider: Adapters.image_enhancement_provider)
      @design = design
      @target_width_px = target_width_px.to_i
      @target_height_px = target_height_px.to_i
      @provider = provider
    end

    def call
      return failure([ I18n.t("designs.enhancement.no_provider") ], code: :unavailable) unless @provider.available?

      @design.update!(enhancement_status: "processing", enhancement_provider: @provider.name.to_s)
      result = @provider.enhance(design: @design, target_width_px: @target_width_px, target_height_px: @target_height_px)

      @design.enhanced_file.attach(io: result.io, filename: "enhanced-#{@design.id}.#{result.content_type.to_s.split('/').last}",
                                   content_type: result.content_type)
      @design.update!(enhancement_status: "done", enhanced_at: Time.current,
                      enhanced_width_px: result.width_px, enhanced_height_px: result.height_px,
                      enhancement_note: I18n.t("designs.quality.enhanced", w: result.width_px, h: result.height_px, provider: @provider.name))
      DomainEvents.publish(:design_enhanced, design_id: @design.id)
      success(design: @design)
    rescue ImageEnhancement::Provider::Unavailable, ImageEnhancement::Provider::Error => e
      @design.update(enhancement_status: "failed", enhancement_note: e.message)
      DomainEvents.publish(:design_enhancement_failed, design_id: @design.id, message: e.message)
      failure([ e.message ], code: :gateway_error)
    end
  end
end
