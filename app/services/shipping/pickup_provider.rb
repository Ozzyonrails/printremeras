module Shipping
  class PickupProvider < Provider
    def code = :pickup
    def requires_address? = false
    def fee_cents(subtotal_cents:) = 0
    def description = [ Setting.pickup_address, Setting.pickup_hours ].reject(&:blank?).join(" · ")
  end
end
