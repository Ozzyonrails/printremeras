require "test_helper"

# Service-level walk through the whole lifecycle: guest → cart → merge → order →
# moderation → fake payment → inventory + rendering → delivery → review → reward.
class OrderFlowTest < ActiveSupport::TestCase
  setup do
    @template = create_template(stock: 5)
    @size = @template.template_sizes.first
    @guest = GuestSession.issue!
    @design = create_design(owner: @guest)
    @cart = Cart.create!(owner: @guest)
    @admin = create_admin
    @operator = create_admin(role: "operator")
  end

  test "full custom order lifecycle" do
    add = Orders::AddToCart.call(cart: @cart, owner: @guest, template_id: @template.id, template_size_id: @size.id, quantity: 2,
                                 placements: [ placement_params(@design, @template.front_area), placement_params(@design, @template.print_area(:back), scale: 0.3) ])
    assert add.success?, add.error_message
    line = Orders::Pricing.line_for(add.cart_item)
    assert_equal 2, line[:sides_count]
    assert_equal 1_800_000, line[:unit_price_cents]

    # Register → guest data merges into the account
    reg = Identity::Register.call(email: "ana@example.com", password: "password123", guest_session: @guest)
    assert reg.success?, reg.error_message
    user = reg.user
    assert_equal user, @design.reload.owner
    assert_nil Cart.find_by(owner: @guest)
    user_cart = user.cart
    assert_equal 1, user_cart.items.count

    # Coupon + quote
    coupon = Coupon.create!(code: "PROMO10", discount_type: "percentage", discount_value: 10, source: "campaign")
    quote = Orders::Quote.call(cart: user_cart, user: user, shipping_method: "pickup", coupon_code: "PROMO10")
    assert quote.success? && quote.valid, quote.errors.inspect
    assert_equal 3_600_000, quote.subtotal_cents
    assert_equal 360_000, quote.discount_cents
    assert_equal 0, quote.shipping_fee_cents
    assert_equal 3_240_000, quote.total_cents
    assert quote.requires_moderation

    # Courier outside CABA rejected
    outside = user.addresses.create!(recipient_name: "Ana", phone: "11", street: "Calle", number: "1", neighborhood: "Centro", postal_code: "1900", city: "La Plata")
    bad = Orders::Quote.call(cart: user_cart, user: user, shipping_method: "courier", address: outside)
    assert_not bad.valid
    assert_includes bad.errors.join, "CABA"

    created = Orders::Create.call(user: user, cart: user_cart, shipping_method: "pickup", coupon_code: "PROMO10")
    assert created.success?, created.error_message
    order = created.order
    assert_equal "pending_approval", order.status
    assert_equal 3_240_000, order.total_cents
    assert_equal 1, coupon.reload.used_count
    assert_equal 0, user_cart.reload.items.count
    assert_equal 2, order.items.first.placements.count
    assert_equal 5, @size.reload.stock, "stock is not reserved before payment"

    # Moderation
    approved = Orders::Approve.call(order: order, admin_user: @operator)
    assert approved.success?, approved.error_message
    assert_equal "awaiting_payment", order.reload.status
    assert AuditLog.exists?(action: "order.artwork_approved")

    # Fake payment + webhook, processed by the job pipeline
    checkout = Payments::StartCheckout.call(order: order, flow: "qr")
    assert checkout.success?, checkout.error_message
    payment = checkout.payment
    assert_match %r{/dev/payments/#{payment.id}}, payment.checkout_url

    perform_enqueued_jobs do
      Adapters.payment_gateway.simulate!(payment: payment, status: "approved")
    end
    assert_equal "approved", payment.reload.status
    assert_equal "paid", order.reload.status
    assert_equal 3, @size.reload.stock, "stock decremented on payment"
    assert order.items.first.print_files.attached?, "print files rendered"
    assert_equal 2, order.items.first.print_files.count
    assert order.items.first.preview.attached?

    # Duplicate webhook is ignored
    event_count = PaymentEvent.count
    perform_enqueued_jobs do
      Payments::HandleWebhook.call(provider: "fake", params: { "payment_id" => payment.provider_payment_id, "status" => "approved", "event_id" => PaymentEvent.last.provider_event_id }, headers: {}, raw_body: "")
    end
    assert_equal event_count, PaymentEvent.count
    assert_equal 3, @size.reload.stock

    # Production → delivery
    %w[preparing in_production ready_for_pickup delivered].each do |s|
      r = Orders::Transition.call(order: order, to: s, actor: @operator)
      assert r.success?, "#{s}: #{r.error_message}"
    end
    assert_not Orders::Transition.call(order: order, to: "paid", actor: @operator).success?
    assert order.reload.can_be_reviewed?

    # Review → approval → reward coupon
    photo = upload_blob(jpeg_file, filename: "me.jpg", content_type: "image/jpeg")
    submitted = Reviews::Submit.call(order: order, user: user, rating: 5, body: "Genial", photo_signed_ids: [ photo.signed_id ])
    assert submitted.success?, submitted.error_message
    review = submitted.review
    assert_not Reviews::Submit.call(order: order, user: user, rating: 4, photo_signed_ids: [ photo.signed_id ]).success?, "one review per order"

    perform_enqueued_jobs do
      assert Reviews::Approve.call(review: review, admin_user: @operator).success?
    end
    review.reload
    assert review.coupon.present?
    assert_equal user, review.coupon.owner
    assert_equal Setting.review_reward_percent, review.coupon.discount_value
    assert_equal 1, review.published_photos.count
    assert_equal ApplicationRecord.public_storage.to_s, review.published_photos.first.blob.service_name

    # Personal coupon rejected for other user, valid for owner
    other = create_user
    assert_equal :not_owner, Coupons::Validate.call(code: review.coupon.code, user: other, subtotal_cents: 100_000).code
    assert Coupons::Validate.call(code: review.coupon.code, user: user, subtotal_cents: 100_000).success?
  end

  test "catalog-only orders skip moderation and cancellation restores stock and coupon" do
    user = create_user
    catalog_design = create_design(owner: nil, source: "catalog", license_note: "own artwork")
    item = CatalogItem.create!(template: @template, title_translations: { "es" => "Diseño A" }, slug: "diseno-a", price_cents: 1_400_000, published: true)
    item.placements.create!(design: catalog_design, print_area: @template.front_area, x: 0.5, y: 0.5, scale: 0.5, rotation: 0)
    cart = Cart.create!(owner: user)
    assert Orders::AddToCart.call(cart: cart, owner: user, template_id: @template.id, template_size_id: @size.id, quantity: 1, catalog_item_id: item.id).success?
    coupon = Coupon.create!(code: "FIX500", discount_type: "fixed_amount", discount_value: 500_000, source: "manual", max_uses: 1)

    created = Orders::Create.call(user: user, cart: cart, shipping_method: "pickup", coupon_code: "FIX500")
    assert created.success?, created.error_message
    order = created.order
    assert_equal "awaiting_payment", order.status
    assert_equal 900_000, order.total_cents
    assert coupon.reload.exhausted?

    payment = Payments::StartCheckout.call(order: order).payment
    perform_enqueued_jobs { Adapters.payment_gateway.simulate!(payment: payment, status: "approved") }
    assert_equal "paid", order.reload.status
    assert_equal 4, @size.reload.stock

    perform_enqueued_jobs do
      assert Orders::Cancel.call(order: order, actor: user).success?
    end
    assert_equal "cancelled", order.reload.status
    assert_equal 5, @size.reload.stock, "stock restored on cancellation"
    assert_equal 0, coupon.reload.used_count, "coupon restored"
  end

  test "amount mismatch flags the order as a problem" do
    user = create_user
    catalog_design = create_design(owner: nil, source: "catalog", license_note: "own")
    item = CatalogItem.create!(template: @template, title_translations: { "es" => "B" }, slug: "b", price_cents: 1_000_000, published: true)
    item.placements.create!(design: catalog_design, print_area: @template.front_area, x: 0.5, y: 0.5, scale: 0.5)
    cart = Cart.create!(owner: user)
    Orders::AddToCart.call(cart: cart, owner: user, template_id: @template.id, template_size_id: @size.id, catalog_item_id: item.id)
    order = Orders::Create.call(user: user, cart: cart, shipping_method: "pickup").order
    payment = Payments::StartCheckout.call(order: order).payment
    perform_enqueued_jobs { Adapters.payment_gateway.simulate!(payment: payment, status: "approved", amount_cents: 1) }
    assert_equal "problem", order.reload.status
    assert_equal "rejected", payment.reload.status
  end

  test "concurrent stock decrement never goes negative" do
    @size.update!(stock: 1)
    user = create_user
    catalog_design = create_design(owner: nil, source: "catalog", license_note: "own")
    item = CatalogItem.create!(template: @template, title_translations: { "es" => "C" }, slug: "c", price_cents: 1_000_000, published: true)
    item.placements.create!(design: catalog_design, print_area: @template.front_area, x: 0.5, y: 0.5, scale: 0.5)
    cart = Cart.create!(owner: user)
    orders = 2.times.map do
      Orders::AddToCart.call(cart: cart, owner: user, template_id: @template.id, template_size_id: @size.id, catalog_item_id: item.id)
      Orders::Create.call(user: user, cart: cart, shipping_method: "pickup").order
    end
    orders.each { |o| Orders::Transition.call(order: o, to: "paid") }
    orders.each { |o| Inventory::Adjust.call(order: o, direction: :decrement) }
    assert_equal 0, @size.reload.stock
    assert_equal 1, orders.count { |o| o.reload.problem? }
  end
end
