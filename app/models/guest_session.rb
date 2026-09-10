class GuestSession < ApplicationRecord
  LIFETIME = 90.days

  has_many :designs, as: :owner, dependent: :nullify
  has_one :cart, as: :owner, dependent: :destroy

  has_secure_token :token, length: 36

  scope :expired, -> { where(expires_at: ...Time.current) }
  scope :unmerged, -> { where(merged_at: nil) }

  def self.issue!
    create!(expires_at: LIFETIME.from_now, last_seen_at: Time.current)
  end

  def expired? = expires_at <= Time.current
  def touch_seen!
    update_columns(last_seen_at: Time.current) if last_seen_at.nil? || last_seen_at < 1.hour.ago
  end
  def locale = nil
end
