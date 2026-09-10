module Designs
  # Re-evaluates whether a design needs enhancement, given how it is actually placed.
  # A 900px file is fine on a pocket print and poor across a full front, so the verdict
  # depends on the placements, not on the file alone.
  class FlagQuality < ApplicationService
    def initialize(design:, placements: nil)
      @design = design
      @placements = placements
    end

    def call
      placements = (@placements || @design.placements.includes(:print_area)).to_a
      shortfall = placements.select(&:low_quality?)

      if shortfall.empty? && placements.any?
        clear_flag if @design.enhancement_status == "needed"
        return success(needed: false, target_width_px: nil, target_height_px: nil)
      end
      return success(needed: @design.needs_enhancement?, target_width_px: nil, target_height_px: nil) if placements.empty?

      target_w = shortfall.map(&:required_width_px).max
      target_h = shortfall.map(&:required_height_px).max
      note = I18n.t("designs.quality.below_min_dpi",
                    dpi: shortfall.map { |p| p.effective_dpi.round }.min,
                    min: shortfall.map { |p| p.print_area.effective_min_dpi }.max,
                    w: target_w, h: target_h)

      if @design.enhancement_status.in?(%w[none needed])
        @design.update!(enhancement_status: "needed", enhancement_note: note)
        DomainEvents.publish(:design_flagged_low_quality, design_id: @design.id)
      end
      success(needed: true, target_width_px: target_w, target_height_px: target_h)
    end

    private

    def clear_flag
      @design.update!(enhancement_status: "none", enhancement_note: nil)
    end
  end
end
