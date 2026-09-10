class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :conversation

  scope :by_activity, -> { order(Arel.sql("last_message_at DESC NULLS LAST")) }
  scope :with_unread_for_admin, -> { where("unread_for_admin > 0") }

  def self.for_user(user) = find_or_create_by!(user: user)
end
