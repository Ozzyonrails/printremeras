class Review < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :order
  belongs_to :user
  belongs_to :reviewed_by, class_name: "AdminUser", optional: true
  belongs_to :coupon, optional: true

  # Pending photos live in the private bucket; on approval they are copied to the
  # public bucket (published_photos) and served through the CDN.
  has_many_attached :photos, service: ApplicationRecord.private_storage do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ], format: :webp
    attachable.variant :large, resize_to_limit: [ 1600, 1600 ], format: :webp, saver: { quality: 85 }
  end
  has_many_attached :published_photos, service: ApplicationRecord.public_storage do |attachable|
    attachable.variant :card, resize_to_fill: [ 480, 600 ], format: :webp, saver: { quality: 80 }, preprocessed: true
    attachable.variant :large, resize_to_limit: [ 1600, 1600 ], format: :webp, saver: { quality: 85 }
  end

  validates :rating, inclusion: { in: 1..5 }
  validates :status, inclusion: { in: STATUSES }
  validates :order_id, uniqueness: true
  validates :body, length: { maximum: 2000 }

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :visible, -> { approved.where(published: true).order(reviewed_at: :desc) }
  scope :for_template, ->(template_id) { joins(order: :items).where(order_items: { template_id: template_id }).distinct }
  scope :for_catalog_item, ->(catalog_item_id) { joins(order: :items).where(order_items: { catalog_item_id: catalog_item_id }).distinct }

  STATUSES.each { |s| define_method("#{s}?") { status == s } }

  def can_resubmit? = rejected? && submission_count <= Setting.review_max_resubmissions
  def visible? = approved? && published?
end
