class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :items
  belongs_to :template
  belongs_to :template_size
  belongs_to :catalog_item, optional: true
  has_many :placements, as: :placeable, dependent: :destroy

  has_one_attached :preview, service: ApplicationRecord.private_storage do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 300, 300 ], format: :webp
  end
  has_many_attached :print_files, service: ApplicationRecord.private_storage

  validates :quantity, numericality: { greater_than_or_equal_to: 1, only_integer: true }
  validates :unit_price_cents, :line_total_cents, numericality: { greater_than_or_equal_to: 0 }

  def custom? = catalog_item_id.nil?
  def title = snapshot["title"] || snapshot["template_name"]
  def size_label = snapshot["size_label"]
  def print_file_for(side) = print_files.find { |f| f.filename.to_s.include?("-#{side}") }
end
