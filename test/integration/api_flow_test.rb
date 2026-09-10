require "test_helper"

class ApiFlowTest < ActionDispatch::IntegrationTest
  setup do
    @template = create_template
    @size = @template.template_sizes.first
  end

  test "guest designs, adds to cart, registers at checkout and places an order" do
    boot = bootstrap_session
    assert_nil boot["user"]
    assert boot["settings"]["shipping_methods"].map { |m| m["code"] }.include?("pickup")
    assert cookies["guest_token"].present?

    get "/api/v1/templates", headers: api_headers
    assert_response :success
    assert_equal 1, json["templates"].size
    get "/api/v1/templates/#{@template.slug}", headers: api_headers
    assert_equal 2, json["template"]["print_areas"].size

    # Direct upload handshake, then PUT to the storage service, then register the design
    file = png_file(1600, 1600)
    checksum = Digest::MD5.file(file.path).base64digest
    api :post, "/api/v1/uploads", { blob: { filename: "art.png", byte_size: File.size(file.path), checksum: checksum, content_type: "image/png" } }
    assert_response :success, response.body
    signed_id = json["signed_id"]
    put json["direct_upload"]["url"], params: File.binread(file.path), headers: json["direct_upload"]["headers"]
    assert_response :no_content

    api :post, "/api/v1/designs", { signed_id: signed_id }
    assert_response :created, response.body
    design_id = json["design"]["id"]
    assert_equal 1600, json["design"]["width_px"]

    # Artwork outside the print area is still a real error...
    api :post, "/api/v1/designs/validate_placement", { template_id: @template.id, placement: { design_id: design_id, print_area_id: @template.front_area.id, x: 0.95, y: 0.5, scale: 0.6 } }
    assert_response :unprocessable_content
    # ...but low resolution is only a warning, never a refusal.
    api :post, "/api/v1/designs/validate_placement", { template_id: @template.id, placement: { design_id: design_id, print_area_id: @template.front_area.id, x: 0.5, y: 0.5, scale: 1.0 } }
    assert_response :success, response.body
    assert json["valid"]
    assert json["placements"].first["low_quality"], "a 1600px file across a 280mm area is below 150 dpi"
    assert_equal 1, json["warnings"].size

    api :post, "/api/v1/cart/items", { template_id: @template.id, template_size_id: @size.id, quantity: 1, placements: [ { design_id: design_id, print_area_id: @template.front_area.id, x: 0.5, y: 0.5, scale: 0.5, rotation: 0 } ] }
    assert_response :created, response.body
    assert_equal 1_500_000, json["cart"]["subtotal_cents"]

    api :post, "/api/v1/orders", { shipping_method: "pickup" }
    assert_response :unauthorized
    assert_equal "login_required", json["code"]

    api :post, "/api/v1/registration", { email: "guest@example.com", password: "password123", first_name: "G" }
    assert_response :created, response.body
    get "/api/v1/cart", headers: api_headers
    assert_equal 1, json["cart"]["items"].size, "guest cart merged"

    api :post, "/api/v1/cart/quote", { shipping_method: "courier" }
    assert_not json["quote"]["valid"]

    api :post, "/api/v1/orders", { shipping_method: "courier", address: { recipient_name: "G", phone: "1155", street: "Av. Corrientes", number: "1234", neighborhood: "San Nicolás", postal_code: "C1043", city: "CABA" } }
    assert_response :created, response.body
    number = json["order"]["number"]
    assert_equal "pending_approval", json["order"]["status"]
    assert_equal Setting.shipping_fee_cents, json["order"]["shipping_fee_cents"]

    # Cannot pay before moderation
    api :post, "/api/v1/orders/#{number}/payments", { flow: "redirect" }
    assert_response :unprocessable_content

    Orders::Approve.call(order: Order.find_by!(number: number), admin_user: create_admin(role: "operator"))
    api :post, "/api/v1/orders/#{number}/payments", { flow: "qr" }
    assert_response :created, response.body
    assert json["payment"]["qr_svg"].include?("<svg")

    get "/api/v1/orders", headers: api_headers
    assert_equal 1, json["orders"].size

    api :delete, "/api/v1/session"
    get "/api/v1/orders", headers: api_headers
    assert_response :unauthorized
  end

  test "delivered order accepts a photo review through the API and issues a coupon" do
    user = create_user
    order = Order.create!(user: user, number: "PR-REV-0001", status: "delivered", shipping_method: "pickup", total_cents: 100, subtotal_cents: 100, delivered_at: 1.day.ago)
    order.items.create!(template: @template, template_size: @size, quantity: 1, unit_price_cents: 100, line_total_cents: 100, snapshot: { "title" => "Remera", "size_label" => "M" })
    bootstrap_session
    api :post, "/api/v1/session", { email: user.email, password: "password123" }
    assert_response :success

    photo = upload_blob(jpeg_file, filename: "yo.jpg", content_type: "image/jpeg")
    api :post, "/api/v1/orders/#{order.number}/review", { rating: 5, body: "Quedó genial", photos: [ photo.signed_id ] }
    assert_response :created, response.body
    review = order.reload.review
    assert_equal 5, review.rating

    perform_enqueued_jobs { Reviews::Approve.call(review: review, admin_user: create_admin(role: "operator")) }
    get "/api/v1/coupons/mine", headers: api_headers
    assert_equal 1, json["coupons"].size
    assert_equal Setting.review_reward_percent, json["coupons"].first["discount_value"]

    get "/api/v1/reviews", headers: api_headers
    assert_equal 1, json["reviews"].size
    assert_equal false, json["has_more"]
    assert_equal 1, json["reviews"].first["photos"].size
  end

  test "webhook endpoint answers 200 and records the event once" do
    user = create_user
    order = Order.create!(user: user, number: "PR-TEST-0001", status: "awaiting_payment", shipping_method: "pickup", total_cents: 100, subtotal_cents: 100)
    order.payments.create!(provider: "fake", amount_cents: 100, external_reference: "PR-TEST-0001-x", provider_payment_id: "fp1", raw_payload: { "simulated_status" => "approved", "simulated_amount_cents" => 100 })
    2.times { post "/webhooks/fake", params: { payment_id: "fp1", status: "approved", event_id: "evt-1" } ; assert_response :ok, response.body }
    assert_equal 1, PaymentEvent.count
    post "/webhooks/unknown", params: { payment_id: "x" }
    assert_response :not_found
    perform_enqueued_jobs
    assert_equal "paid", order.reload.status
  end

  test "admin login and moderation page render" do
    admin = create_admin
    get "/admin/orders"
    assert_redirected_to "/admin/session/new"
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
    assert_redirected_to "/admin"
    get "/admin"
    assert_response :success
    %w[/admin/orders /admin/moderation /admin/reviews /admin/coupons /admin/templates /admin/catalog_items /admin/customers /admin/conversations /admin/settings /admin/audit_logs /admin/admin_users /admin/coupons/new /admin/templates/new].each do |path|
      get path
      assert_response :success, path
    end
    get "/admin/templates/#{@template.id}"
    assert_response :success
    # The job dashboard itself needs a real queue adapter, which the test adapter is not,
    # so assert the wiring that makes it sit behind the admin session instead.
    assert_equal "Admin::BaseController", MissionControl::Jobs.base_controller_class
    assert_equal false, MissionControl::Jobs.http_basic_auth_enabled
    patch "/admin/settings", params: { settings: { shipping_fee_cents: "123", rush_enabled: "1" } }
    assert_redirected_to "/admin/settings"
    assert_equal 123, Setting.shipping_fee_cents
    assert Setting.rush_enabled
    assert AuditLog.exists?(action: "settings.changed")
  end

  test "operator cannot access admin-only areas" do
    op = create_admin(role: "operator")
    post "/admin/session", params: { email: op.email, password: "supersecret123" }
    get "/admin/settings"
    assert_redirected_to "/admin"
  end

  test "spa catch-all and health" do
    get "/up"
    assert_response :success
    get "/templates/whatever"
    assert_includes [ 200, 503 ], response.status
  end
end
