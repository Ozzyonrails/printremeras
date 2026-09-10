class Coupon < ApplicationRecord
  DISCOUNT_TYPES = %w[percentage fixed_amount].freeze
  SOURCES = %w[review_reward manual campaign].freeze

  belongs_to :owner, class_name: "User", optional: true
  has_many :redemptions, class_name: "CouponRedemption", dependent: :destroy
  has_many :orders, dependent: :nullify
  has_one :review, dependent: :nullify

  normalizes :code, with: ->(c) { c.to_s.strip.upcase.gsub(/[^A-Z0-9-]/, "") }
  validates :code, presence: true, uniqueness: true, length: { in: 4..32 }
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }
  validates :source, inclusion: { in: SOURCES }
  validates :discount_value, numericality: { greater_than: 0, only_integer: true }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?
  validates :max_uses, numericality: { greater_than: 0, only_integer: true }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :personal, -> { where.not(owner_id: nil) }

  def self.generate_code(prefix = "PR")
    loop do
      code = "#{prefix}-#{SecureRandom.alphanumeric(6).upcase}"
      return code unless exists?(code: code)
    end
  end

  def percentage? = discount_type == "percentage"
  def fixed_amount? = discount_type == "fixed_amount"
  def personal? = owner_id.present?
  def exhausted? = max_uses.present? && used_count >= max_uses
  def started? = valid_from.nil? || valid_from <= Time.current
  def expired? = valid_until.present? && valid_until < Time.current
  def currently_valid? = active? && started? && !expired? && !exhausted?

  def discount_for(subtotal_cents)
    amount = percentage? ? (subtotal_cents * discount_value / 100.0).round : discount_value
    [ amount, subtotal_cents ].min
  end
end
