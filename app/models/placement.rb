# Where a design sits on one side of a garment. x/y are the artwork centre as fractions
# of the print area; scale is the artwork width as a fraction of the print area width;
# rotation in degrees. Geometry checks run in physical (mm) space: what gets printed.
class Placement < ApplicationRecord
  MIN_SCALE = 0.05
  MAX_SCALE = 1.0

  belongs_to :design
  belongs_to :print_area
  belongs_to :placeable, polymorphic: true

  validates :x, :y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :scale, numericality: { greater_than_or_equal_to: MIN_SCALE, less_than_or_equal_to: MAX_SCALE }
  validates :rotation, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validate :design_has_dimensions
  validate :inside_print_area
  validate :meets_min_dpi, if: -> { Setting.enforce_min_dpi }

  # --- geometry ---------------------------------------------------------
  def artwork_width_mm = scale.to_f * print_area.width_mm.to_f
  def artwork_height_mm = artwork_width_mm * design.effective_height_px.to_f / design.effective_width_px.to_f

  def bounding_box_mm
    rad = rotation.to_f * Math::PI / 180
    w, h = artwork_width_mm, artwork_height_mm
    bw = (w * Math.cos(rad)).abs + (h * Math.sin(rad)).abs
    bh = (w * Math.sin(rad)).abs + (h * Math.cos(rad)).abs
    cx = x.to_f * print_area.width_mm.to_f
    cy = y.to_f * print_area.height_mm.to_f
    { left: cx - bw / 2, top: cy - bh / 2, right: cx + bw / 2, bottom: cy + bh / 2 }
  end

  def within_area?(tolerance_mm: 0.5)
    box = bounding_box_mm
    box[:left] >= -tolerance_mm && box[:top] >= -tolerance_mm &&
      box[:right] <= print_area.width_mm.to_f + tolerance_mm && box[:bottom] <= print_area.height_mm.to_f + tolerance_mm
  end

  def effective_dpi
    return 0 if design.effective_width_px.zero? || artwork_width_mm.zero?
    design.effective_width_px.to_f / (artwork_width_mm / 25.4)
  end

  def low_quality? = effective_dpi < print_area.effective_min_dpi

  # Pixel size the artwork would need to reach the area's minimum DPI at this placement.
  # Used to brief an upscaling provider.
  # Rounded up: a target that lands a fraction of a pixel short would leave the artwork
  # flagged as low quality even after it has been upscaled.
  def required_width_px = (print_area.effective_min_dpi * artwork_width_mm / 25.4).ceil
  def required_height_px = (print_area.effective_min_dpi * artwork_height_mm / 25.4).ceil

  def side = print_area.side

  def to_params
    { design_id: design_id, print_area_id: print_area_id, x: x.to_f, y: y.to_f, scale: scale.to_f, rotation: rotation.to_f }
  end

  private

  def design_has_dimensions
    errors.add(:design, :missing_dimensions) if design && (design.effective_width_px.zero? || design.effective_height_px.zero?)
  end

  def inside_print_area
    return if design.nil? || print_area.nil? || errors[:design].any?
    errors.add(:base, :outside_print_area) unless within_area?
  end

  # Only runs when Setting.enforce_min_dpi is on. By default low-resolution artwork is
  # accepted and flagged for enhancement instead (see Designs::FlagQuality).
  def meets_min_dpi
    return if design.nil? || print_area.nil? || errors[:design].any?
    errors.add(:base, :low_dpi) if low_quality?
  end
end
