class PrintArea < ApplicationRecord
  SIDES = %w[front back].freeze

  belongs_to :template, inverse_of: :print_areas
  has_many :placements, dependent: :restrict_with_error
  has_one_attached :mockup, service: ApplicationRecord.public_storage do |attachable|
    attachable.variant :card, resize_to_limit: [ 600, 600 ], format: :webp, saver: { quality: 82 }, preprocessed: true
    attachable.variant :editor, resize_to_limit: [ 1200, 1200 ], format: :webp, saver: { quality: 85 }, preprocessed: true
    attachable.variant :thumb, resize_to_limit: [ 240, 240 ], format: :webp, preprocessed: true
  end

  validates :side, inclusion: { in: SIDES }, uniqueness: { scope: :template_id }
  validates :x, :y, :w, :h, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :w, :h, numericality: { greater_than: 0 }
  validates :width_mm, :height_mm, numericality: { greater_than: 0 }
  validates :min_dpi, numericality: { greater_than: 0 }
  validate :rectangle_inside_mockup

  scope :ordered, -> { order(Arel.sql("CASE side WHEN 'front' THEN 0 ELSE 1 END")) }

  def effective_min_dpi = min_dpi.presence || Setting.min_dpi
  def aspect_mm = width_mm.to_f / height_mm.to_f

  # Pixel aspect ratio of the drawn rectangle on the mockup, used to warn admins when
  # it drifts from the physical (mm) aspect ratio.
  def aspect_px
    return nil unless mockup_width_px && mockup_height_px
    (w.to_f * mockup_width_px) / (h.to_f * mockup_height_px)
  end

  def aspect_mismatch?
    aspect_px && ((aspect_px - aspect_mm).abs / aspect_mm) > 0.05
  end

  private

  def rectangle_inside_mockup
    errors.add(:w, :exceeds_mockup) if x.to_f + w.to_f > 1.0001
    errors.add(:h, :exceeds_mockup) if y.to_f + h.to_f > 1.0001
  end
end
