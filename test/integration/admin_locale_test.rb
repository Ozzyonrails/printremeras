require "test_helper"

class AdminLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    post "/admin/session", params: { email: @admin.email, password: "supersecret123" }
  end

  test "the top bar switcher stores the choice and translates the admin" do
    get "/admin"
    assert_response :success
    assert_match "Inicio", response.body
    assert_match "locale-switch", response.body

    patch "/admin/locale", params: { locale: "ru" }
    assert_equal "ru", @admin.reload.locale

    get "/admin"
    assert_match "Главная", response.body, "the dashboard must come back in Russian"
    assert_match "Заказы", response.body

    patch "/admin/locale", params: { locale: "es" }
    get "/admin"
    assert_match "Inicio", response.body
  end

  test "an unknown language is refused rather than stored" do
    patch "/admin/locale", params: { locale: "klingon" }
    assert_equal "es", @admin.reload.locale
    follow_redirect!
    assert_match I18n.t("admin.locales.unknown"), response.body
  end

  test "the money tile keeps its own size class so long amounts stay inside the card" do
    user = create_user
    Order.create!(user: user, number: Order.generate_number, status: "delivered", shipping_method: "pickup",
                  subtotal_cents: 123_456_789, total_cents: 123_456_789, paid_at: 1.day.ago)
    get "/admin"
    assert_response :success
    assert_match "n-money", response.body
    assert_match Money.format(123_456_789), response.body
  end
end
