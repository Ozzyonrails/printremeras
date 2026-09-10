# Append-only. No update/destroy is ever allowed.
class AuditLog < ApplicationRecord
  belongs_to :admin_user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def readonly? = persisted?
  before_destroy { throw :abort }

  def self.record!(action:, admin_user: nil, subject: nil, change_set: {})
    create!(action: action.to_s, admin_user: admin_user, subject: subject, change_set: change_set || {}, created_at: Time.current)
  end
end
