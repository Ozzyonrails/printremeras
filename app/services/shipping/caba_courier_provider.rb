module Shipping
  # Courier delivery restricted to Ciudad Autónoma de Buenos Aires (postal codes 1000–1499,
  # optionally prefixed with "C").
  class CabaCourierProvider < Provider
    CABA_POSTAL_RANGE = (1000..1499)

    def code = :courier
    def requires_address? = true
    def fee_cents(subtotal_cents:) = Setting.shipping_fee_cents
    def available? = Setting.courier_enabled
    def description = I18n.t("shipping.courier_description")

    def address_errors(address)
      return [ I18n.t("shipping.errors.address_required") ] if address.nil?
      serviceable?(address) ? [] : [ I18n.t("shipping.errors.outside_caba") ]
    end

    def serviceable?(address)
      digits = address.postal_code.to_s.upcase.delete_prefix("C")[/\d{4}/]
      digits.present? && CABA_POSTAL_RANGE.cover?(digits.to_i) && address.city.to_s.strip.casecmp?("CABA")
    end
  end
end
