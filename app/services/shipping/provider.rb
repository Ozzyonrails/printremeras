module Shipping
  # Port: every shipping method implements this interface. Registered in
  # config.x.shipping.providers and resolved through Adapters.shipping_provider(:code).
  class Provider
    def code = raise(NotImplementedError)
    def requires_address? = raise(NotImplementedError)
    def fee_cents(subtotal_cents:) = raise(NotImplementedError)
    def available? = true
    # Returns an array of error messages (empty when the address is serviceable).
    def address_errors(_address) = []
    def label = I18n.t("shipping.methods.#{code}")
    def description = nil

    def to_h
      { code: code, label: label, description: description, requires_address: requires_address?, fee_cents: fee_cents(subtotal_cents: 0), available: available? }
    end
  end
end
