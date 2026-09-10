module Orders
  # Computes the checkout totals for a cart without side effects. Shared by the cart
  # page, the checkout summary and Orders::Create (which freezes the result).
  class Quote < ApplicationService
    Line = Struct.new(:item, :sides_count, :unit_price_cents, :line_total_cents, keyword_init: true)

    def initialize(cart:, user:, shipping_method:, address: nil, coupon_code: nil, rush: false)
      @cart = cart
      @user = user
      @shipping_method = shipping_method.to_s.presence || "pickup"
      @address = address
      @coupon_code = coupon_code
      @rush = (ActiveModel::Type::Boolean.new.cast(rush) || false) && Setting.rush_enabled
    end

    def call
      items = @cart.items.includes(:template, :template_size, :catalog_item, placements: [ :print_area, :design ])
      return failure([ I18n.t("cart.errors.empty") ], code: :empty) if items.empty?

      errors = []
      lines = items.map do |item|
        errors << I18n.t("cart.errors.out_of_stock", item: item.template.name, size: item.template_size.label) if item.template_size.stock < item.quantity
        errors << I18n.t("cart.errors.template_inactive", item: item.template.name) unless item.template.active?
        errors << I18n.t("cart.errors.no_artwork", item: item.template.name) if item.custom? && item.placements.empty?
        Line.new(item: item, **Orders::Pricing.line_for(item))
      end
      subtotal = lines.sum(&:line_total_cents)

      provider = shipping_provider
      return failure([ I18n.t("shipping.errors.unknown_method") ], code: :invalid) unless provider
      errors << I18n.t("shipping.errors.unavailable") unless provider.available?
      errors.concat(provider.address_errors(@address)) if provider.requires_address?

      coupon = nil
      discount = 0
      coupon_error = nil
      if @coupon_code.present?
        cv = Coupons::Validate.call(code: @coupon_code, user: @user, subtotal_cents: subtotal)
        if cv.success?
          coupon = cv.coupon
          discount = cv.discount_cents
        else
          coupon_error = cv.error_message
          errors << coupon_error
        end
      end

      rush_fee = @rush ? Setting.rush_fee_cents : 0
      shipping_fee = provider.fee_cents(subtotal_cents: subtotal)
      total = subtotal - discount + rush_fee + shipping_fee

      success(lines: lines, subtotal_cents: subtotal, discount_cents: discount, coupon: coupon, coupon_error: coupon_error,
              rush: @rush, rush_fee_cents: rush_fee, shipping_fee_cents: shipping_fee, total_cents: total,
              shipping_method: provider.code.to_s, errors: errors, valid: errors.empty?,
              requires_moderation: lines.any? { |l| l.item.custom? })
    end

    private

    def shipping_provider
      Adapters.shipping_provider(@shipping_method)
    rescue Adapters::NotRegistered
      nil
    end
  end
end
