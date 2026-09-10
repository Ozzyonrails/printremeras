class Message < ApplicationRecord
  belongs_to :conversation, inverse_of: :messages
  belongs_to :sender, polymorphic: true
  belongs_to :order, optional: true
  has_many_attached :attachments, service: ApplicationRecord.private_storage do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 320, 320 ], format: :webp
  end

  validates :body, presence: true, unless: -> { attachments.attached? || order_id.present? }
  validates :body, length: { maximum: 4000 }

  def from_admin? = sender_type == "AdminUser"
  def from_user? = sender_type == "User"
end
