class Order < ApplicationRecord
  STATUSES = %w[
    draft pending_approval awaiting_payment paid preparing in_production
    awaiting_courier ready_for_pickup in_transit delivered
    rejected cancelled problem refunded
  ].freeze
  TERMINAL = %w[rejected cancelled refunded].freeze
  CUSTOMER_CANCELLABLE = %w[pending_approval awaiting_payment paid preparing in_production].freeze
  STOCK_HOLDING = %w[paid preparing in_production awaiting_courier ready_for_pickup in_transit delivered problem].freeze
  SHIPPING_METHODS = %w[pickup courier].freeze

  belongs_to :user
  belongs_to :coupon, optional: true
  has_many :items, class_name: "OrderItem", dependent: :destroy, inverse_of: :order
  has_many :placements, through: :items
  has_many :status_transitions, class_name: "OrderStatusTransition", dependent: :destroy
  has_many :payments, dependent: :destroy
  has_one :review, dependent: :destroy
  has_many :messages, dependent: :nullify
  has_one :coupon_redemption, dependent: :destroy

  validates :number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :shipping_method, inclusion: { in: SHIPPING_METHODS }
  validates :subtotal_cents, :discount_cents, :rush_fee_cents, :shipping_fee_cents, :total_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :with_status, ->(s) { s.present? ? where(status: s) : all }
  scope :placed, -> { where.not(status: "draft") }

  def self.generate_number
    loop do
      candidate = "PR-#{Time.current.strftime('%y%m%d')}-#{SecureRandom.alphanumeric(4).upcase}"
      return candidate unless exists?(number: candidate)
    end
  end

  STATUSES.each { |s| define_method("#{s}?") { status == s } }

  def terminal? = TERMINAL.include?(status)
  def custom? = items.any?(&:custom?)
  def pickup? = shipping_method == "pickup"
  def courier? = shipping_method == "courier"
  def sides_total = items.sum(&:sides_count)
  def holds_stock? = STOCK_HOLDING.include?(status)
  def paid_or_later? = STOCK_HOLDING.include?(status)
  def customer_can_cancel? = CUSTOMER_CANCELLABLE.include?(status)
  def review_window_open?
    delivered? && delivered_at.present? && delivered_at >= Setting.review_window_days.days.ago
  end
  def can_be_reviewed? = review_window_open? && review.nil?
  def latest_payment = payments.order(created_at: :desc).first
  def to_param = number
end
