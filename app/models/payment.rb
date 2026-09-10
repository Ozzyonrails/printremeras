class Payment < ApplicationRecord
  STATUSES = %w[pending approved rejected refunded cancelled].freeze
  FLOWS = %w[redirect qr].freeze

  belongs_to :order

  validates :provider, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :flow, inclusion: { in: FLOWS }
  validates :external_reference, presence: true

  scope :approved, -> { where(status: "approved") }

  def approved? = status == "approved"
  def pending? = status == "pending"
end
