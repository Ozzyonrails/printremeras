require "test_helper"

# The simulator marks orders paid without money moving. It must be unreachable on a public
# deployment even if the fake gateway is selected there by mistake.
class FakePaymentGuardTest < ActionDispatch::IntegrationTest
  setup do
    user = create_user
    @order = Order.create!(user: user, number: Order.generate_number, status: "awaiting_payment",
                           shipping_method: "pickup", subtotal_cents: 100, total_cents: 100)
    @payment = @order.payments.create!(provider: "fake", amount_cents: 100, external_reference: "ref-1")
  end

  test "reachable outside production with the fake gateway" do
    get "/dev/payments/#{@payment.id}"
    assert_response :success
  end

  test "hidden in production even when the fake gateway is configured" do
    with_rails_env("production") do
      get "/dev/payments/#{@payment.id}"
      assert_response :not_found
      post "/dev/payments/#{@payment.id}/simulate", params: { status: "approved" }
      assert_response :not_found
    end
    assert_equal "awaiting_payment", @order.reload.status, "no order may be marked paid through it"
  end

  test "a private staging environment can opt in explicitly" do
    with_rails_env("production") do
      ENV["ALLOW_FAKE_PAYMENTS"] = "true"
      get "/dev/payments/#{@payment.id}"
      assert_response :success
    end
  ensure
    ENV.delete("ALLOW_FAKE_PAYMENTS")
  end
end
