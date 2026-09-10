class Design < ApplicationRecord
  include HasOwner

  SOURCES = %w[user catalog].freeze
  MODERATION = %w[pending approved rejected].freeze
  ALLOWED_TYPES = %w[image/png image/jpeg image/webp].freeze

  has_one_attached :file, service: ApplicationRecord.private_storage do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ], format: :webp
  end
  # The upscaled version produced by ImageEnhancement; the original upload is kept.
  has_one_attached :enhanced_file, service: ApplicationRecord.private_storage do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ], format: :webp
  end
  has_many :placements, dependent: :restrict_with_error

  ENHANCEMENT_STATUSES = %w[none needed requested processing done failed].freeze

  validates :enhancement_status, inclusion: { in: ENHANCEMENT_STATUSES }
  # "done" and an attached enhanced file must not drift apart, or the API would report an
  # improved design while still serving the original pixels.
  validate :enhanced_file_present_when_done
  validates :source, inclusion: { in: SOURCES }
  validates :moderation_status, inclusion: { in: MODERATION }
  validates :width_px, :height_px, numericality: { greater_than: 0 }, allow_nil: true

  scope :catalog, -> { where(source: "catalog") }
  scope :needing_enhancement, -> { where(enhancement_status: %w[needed requested failed]) }

  def catalog? = source == "catalog"
  def enhanced? = enhancement_status == "done" && enhanced_file.attached?
  def needs_enhancement? = enhancement_status.in?(%w[needed requested processing failed])

  # Rendering and DPI use the best available file: the upscaled one once it exists.
  def print_ready_file = enhanced? ? enhanced_file : file
  def effective_width_px = (enhanced? ? enhanced_width_px : width_px).to_i
  def effective_height_px = (enhanced? ? enhanced_height_px : height_px).to_i
  def aspect_ratio = effective_width_px.to_f / effective_height_px.to_f
  def owned_by?(owner) = owner.present? && self.owner == owner

  private

  def enhanced_file_present_when_done
    errors.add(:enhanced_file, :blank) if enhancement_status == "done" && !enhanced_file.attached?
  end
end
