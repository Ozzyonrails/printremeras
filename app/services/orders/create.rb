module Orders
  # Places an order from the cart: freezes prices into OrderItems, copies placements,
  # redeems the coupon, and enters the state machine (pending_approval for custom
  # artwork, awaiting_payment for catalog-only orders). Stock is NOT touched here.
  class Create < ApplicationService
    def initialize(user:, cart:, shipping_method:, address: nil, coupon_code: nil, rush: false, customer_notes: nil, locale: nil)
      @user = user
      @cart = cart
      @shipping_method = shipping_method
      @address = address
      @coupon_code = coupon_code
      @rush = rush
      @notes = customer_notes
      @locale = locale
    end

    def call
      quote = Orders::Quote.call(cart: @cart, user: @user, shipping_method: @shipping_method, address: @address, coupon_code: @coupon_code, rush: @rush)
      return failure(quote.errors, code: quote.code) if quote.failure?
      return failure(quote.errors, code: :invalid) unless quote.valid

      order = nil
      ActiveRecord::Base.transaction do
        order = Order.create!(
          user: @user, number: Order.generate_number, status: "draft", locale: @locale.presence || @user.locale,
          subtotal_cents: quote.subtotal_cents, discount_cents: quote.discount_cents, rush: quote.rush,
          rush_fee_cents: quote.rush_fee_cents, shipping_fee_cents: quote.shipping_fee_cents, total_cents: quote.total_cents,
          shipping_method: quote.shipping_method, shipping_address: @address&.to_snapshot || {},
          requires_moderation: quote.requires_moderation, customer_notes: @notes.to_s.presence, placed_at: Time.current
        )
        quote.lines.each { |line| copy_line(order, line) }
        flag_artwork_quality(order)

        if quote.coupon
          redeemed = Coupons::Redeem.call(coupon: quote.coupon, order: order, discount_cents: quote.discount_cents)
          raise ActiveRecord::Rollback unless redeemed.success?
        end

        first_state = quote.requires_moderation ? "pending_approval" : "awaiting_payment"
        Orders::Transition.call(order: order, to: first_state, actor: @user, skip_event: true).tap { |r| raise ActiveRecord::Rollback if r.failure? }
        @cart.items.destroy_all
      end
      return failure([ I18n.t("orders.errors.could_not_place") ], code: :invalid) if order.nil? || !order.persisted?

      DomainEvents.publish(:order_created, order_id: order.id)
      success(order: order)
    end

    private

    def copy_line(order, line)
      item = line.item
      order_item = order.items.create!(
        template: item.template, template_size: item.template_size, catalog_item: item.catalog_item, quantity: item.quantity,
        unit_price_cents: line.unit_price_cents, line_total_cents: line.line_total_cents, sides_count: line.sides_count,
        snapshot: {
          "template_name" => item.template.name, "template_slug" => item.template.slug, "color_name" => item.template.color_name,
          "color_hex" => item.template.color_hex, "size_label" => item.template_size.label,
          "title" => item.catalog_item&.title || item.template.name, "catalog_slug" => item.catalog_item&.slug,
          "base_price_cents" => item.template.base_price_cents, "print_price_cents" => item.catalog_item ? nil : item.template.print_price_for(line.sides_count),
          "sides" => item.placements.map { |p| p.print_area.side }
        }
      )
      item.placements.each do |p|
        order_item.placements.create!(design: p.design, print_area: p.print_area, x: p.x, y: p.y, scale: p.scale, rotation: p.rotation)
      end
    end

    # Low-resolution artwork does not block the order; it is marked so the moderation
    # queue can see it and an upscaling provider can be asked to improve it.
    def flag_artwork_quality(order)
      placements = order.reload.placements.includes(:design, :print_area).to_a
      low = placements.select(&:low_quality?)
      order.update_columns(low_quality_artwork: low.any?)
      low.group_by(&:design).each do |design, group|
        result = Designs::FlagQuality.call(design: design, placements: group)
        next unless result.needed && Setting.auto_request_enhancement
        Designs::RequestEnhancement.call(design: design, target_width_px: result.target_width_px, target_height_px: result.target_height_px)
      end
    end
  end
end
