module Designs
  # Marks a design for upscaling and, when a provider is configured, queues the work.
  # Without a provider it stays in "requested" so the queue is ready later.
  class RequestEnhancement < ApplicationService
    def initialize(design:, admin_user: nil, target_width_px: nil, target_height_px: nil)
      @design = design
      @admin = admin_user
      @target_width_px = target_width_px
      @target_height_px = target_height_px
    end

    def call
      return failure([ I18n.t("designs.enhancement.disabled") ], code: :unavailable) unless Setting.image_enhancement_enabled
      return failure([ I18n.t("designs.enhancement.already_done") ], code: :invalid) if @design.enhancement_status == "done"

      target = targets
      @design.update!(enhancement_status: "requested", enhancement_requested_at: Time.current,
                      enhancement_note: @design.enhancement_note.presence || I18n.t("designs.quality.manual_request"))
      AuditLog.record!(action: "design.enhancement_requested", admin_user: @admin, subject: @design,
                       change_set: { "target_width_px" => target[:width], "target_height_px" => target[:height] })
      DomainEvents.publish(:design_enhancement_requested, design_id: @design.id,
                           target_width_px: target[:width], target_height_px: target[:height])
      Designs::EnhanceJob.perform_later(@design.id, target[:width], target[:height]) if Adapters.image_enhancement_provider.available?
      success(design: @design, queued: Adapters.image_enhancement_provider.available?)
    end

    private

    # Falls back to the size that would satisfy the flagged placements.
    def targets
      return { width: @target_width_px, height: @target_height_px } if @target_width_px.to_i.positive?
      flagged = Designs::FlagQuality.call(design: @design)
      { width: flagged.target_width_px || (@design.width_px.to_i * 2), height: flagged.target_height_px || (@design.height_px.to_i * 2) }
    end
  end
end
