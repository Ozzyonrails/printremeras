require "test_helper"

# Renders every admin page with real data after a complete order lifecycle, and every mail template.
class AdminPagesTest < ActionDispatch::IntegrationTest
  setup do
    @template = create_template
    @size = @template.template_sizes.first
    @admin = create_admin
    @user = create_user
    design = create_design(owner: @user)
    cart = Cart.create!(owner: @user)
    Orders::AddToCart.call(cart: cart, owner: @user, template_id: @template.id, template_size_id: @size.id, placements: [ placement_params(design, @template.front_area) ]).tap { |r| raise r.error_message if r.failure? }
    @order = Orders::Create.call(user: @user, cart: cart, shipping_method: "pickup").tap { |r| raise r.error_message if r.failure? }.order
    catalog_design = create_design(owner: nil, source: "catalog")
    @item = CatalogItem.create!(template: @template, title_translations: { "es" => "Diseño" }, slug: "diseno", price_cents: 1_000, published: false)
    @item.placements.create!(design: catalog_design, print_area: @template.front_area, x: 0.5, y: 0.5, scale: 0.5)
    post "/admin/session", params: { email: @admin.email, password: "supersecret123" }
  end

  test "moderation, order, payment, review, chat and catalog pages render through the lifecycle" do
    get "/admin/moderation/#{@order.number}"
    assert_response :success
    post "/admin/moderation/#{@order.number}/approve"
    assert_redirected_to "/admin/moderation"
    assert_equal "awaiting_payment", @order.reload.status

    payment = Payments::StartCheckout.call(order: @order).payment
    get "/dev/payments/#{payment.id}"
    assert_response :success
    perform_enqueued_jobs { post "/dev/payments/#{payment.id}/simulate", params: { status: "approved" } }
    assert_equal "paid", @order.reload.status

    get "/admin/orders/#{@order.number}"
    assert_response :success
    assert_includes response.body, "-front.png"
    get "/admin/orders/#{@order.number}/artwork"
    assert_response :success
    assert_equal "application/zip", response.media_type

    %w[preparing in_production ready_for_pickup delivered].each do |s|
      post "/admin/orders/#{@order.number}/transition", params: { to: s }
      assert_redirected_to "/admin/orders/#{@order.number}"
    end
    post "/admin/orders/#{@order.number}/transition", params: { to: "paid" }
    follow_redirect!
    assert_includes response.body, "flash-alert"

    review = Reviews::Submit.call(order: @order.reload, user: @user, rating: 4, photo_signed_ids: [ upload_blob(jpeg_file, filename: "p.jpg", content_type: "image/jpeg").signed_id ]).tap { |r| raise r.error_message if r.failure? }.review
    get "/admin/reviews"
    assert_response :success
    get "/admin/reviews/#{review.id}"
    assert_response :success
    perform_enqueued_jobs { post "/admin/reviews/#{review.id}/approve", params: { published: "1" } }
    assert review.reload.coupon.present?
    get "/admin/reviews?status=approved"
    assert_response :success
    get "/admin/coupons"
    assert_response :success
    assert_includes response.body, review.coupon.code

    conversation = Conversation.for_user(@user)
    Messaging::SendMessage.call(conversation: conversation, sender: @user, body: "Hola", order_id: @order.id)
    get "/admin/conversations"
    assert_response :success
    get "/admin/conversations/#{conversation.id}"
    assert_response :success
    post "/admin/conversations/#{conversation.id}/messages.json", params: { body: "Hola!", order_id: @order.id }.to_json, headers: { "Content-Type" => "application/json", "X-CSRF-Token" => "test" }
    assert_response :success
    assert_equal 0, conversation.reload.unread_for_admin

    get "/admin/customers/#{@user.id}"
    assert_response :success
    get "/admin/catalog_items"
    assert_response :success
    get "/admin/catalog_items/#{@item.id}/editor"
    assert_response :success
    assert_includes response.body, "data-react=\"design-editor\""
    get "/admin/catalog_items/#{@item.id}/edit"
    assert_response :success
    patch "/admin/catalog_items/#{@item.id}.json", params: { placements: [ { design_id: @item.placements.first.design_id, print_area_id: @template.front_area.id, x: 0.5, y: 0.5, scale: 0.4, rotation: 10 } ] }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :success, response.body
    perform_enqueued_jobs
    assert @item.reload.preview.attached?
    post "/admin/catalog_items/#{@item.id}/publish", params: { published: "1" }
    assert @item.reload.published?
    get "/admin/templates/#{@template.id}"
    assert_response :success
    assert_includes response.body, "data-react=\"print-area-editor\""
    get "/admin/audit_logs"
    assert_response :success
    get "/admin/artwork"
    assert_response :success
    get "/admin"
    assert_response :success
  end

  test "every notification and account mail renders in both locales" do
    review = Review.new(order: @order, user: @user, rating: 5, body: "x", status: "approved", reviewed_at: Time.current)
    review.photos.attach(upload_blob(jpeg_file, filename: "p.jpg", content_type: "image/jpeg"))
    review.save!
    review.update!(coupon: Coupon.create!(code: "GRACIAS-1", discount_type: "percentage", discount_value: 25, source: "review_reward", owner: @user, max_uses: 1, valid_until: 30.days.from_now))
    message = Messaging::SendMessage.call(conversation: Conversation.for_user(@user), sender: @admin, body: "Hola").message
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        %i[order_approved order_rejected order_paid order_cancelled order_problem order_refunded payment_failed].each do |m|
          mail = Notifications::CustomerMailer.with(user: @user, order: @order).public_send(m)
          assert mail.body.encoded.present?, "#{locale} #{m}"
          assert_equal [ @user.email ], mail.to
        end
        Notifications::CustomerMailer.with(user: @user, order: @order, to: "ready_for_pickup").order_status_changed.deliver_now
        Notifications::CustomerMailer.with(user: @user, review: review).review_approved.deliver_now
        Notifications::CustomerMailer.with(user: @user, review: review).review_rejected.deliver_now
        Notifications::CustomerMailer.with(user: @user, order: @order).review_invitation.deliver_now
        Notifications::CustomerMailer.with(user: @user, message: message).message_created.deliver_now
        %i[order_created order_paid order_cancelled order_problem].each { |m| Notifications::OperatorMailer.with(order: @order).public_send(m).deliver_now }
        Notifications::OperatorMailer.with(review: review).review_submitted.deliver_now
        Notifications::OperatorMailer.with(message: message).message_created.deliver_now
        Identity::AccountMailer.with(user: @user, token: "t").confirmation.deliver_now
        Identity::AccountMailer.with(user: @user, token: "t").password_reset.deliver_now
      end
    end
    assert_equal 26, ActionMailer::Base.deliveries.size
  end

  test "notification pipeline delivers order_paid to customer and operator via email" do
    Orders::Transition.call(order: @order, to: "awaiting_payment")
    assert_emails 2 do
      perform_enqueued_jobs { Orders::Transition.call(order: @order, to: "paid") }
    end
  end
end
