class AdminUser < ApplicationRecord
  ROLES = %w[operator admin].freeze
  has_secure_password

  has_many :audit_logs, dependent: :nullify

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 10 }, allow_nil: true

  scope :active, -> { where(active: true) }

  def admin? = role == "admin"
  def operator? = role == "operator"
  def full_name = name
  def display_name = name
end
