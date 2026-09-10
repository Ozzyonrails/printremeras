# Inbound provider notifications. The unique (provider, provider_event_id) index is the
# idempotency guard: providers re-send webhooks and we process each one exactly once.
class PaymentEvent < ApplicationRecord
  belongs_to :order, optional: true
  validates :provider, :provider_event_id, presence: true
  validates :provider_event_id, uniqueness: { scope: :provider }

  def processed? = processed_at.present?
end
