class User < ApplicationRecord
  has_secure_password validations: false

  has_many :designs, as: :owner, dependent: :nullify
  has_one :cart, as: :owner, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :addresses, dependent: :destroy
  has_many :coupons, foreign_key: :owner_id, inverse_of: :owner, dependent: :nullify
  has_many :reviews, dependent: :restrict_with_error
  has_one :conversation, dependent: :destroy

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :password, presence: true, on: :create, unless: :google_uid?
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }

  generates_token_for :password_reset, expires_in: 30.minutes do
    password_salt&.last(10)
  end
  generates_token_for :email_confirmation, expires_in: 3.days do
    email
  end

  def confirmed? = confirmed_at.present?
  def full_name = [ first_name, last_name ].reject(&:blank?).join(" ").presence || email
  def display_name = first_name.presence || email.split("@").first

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end
end
