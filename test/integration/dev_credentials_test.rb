require "test_helper"

# The demo accounts are a development convenience. The important guarantee is that they
# never reach a production build, so these tests pin both directions.
class DevCredentialsTest < ActionDispatch::IntegrationTest
  test "the storefront receives the shortcuts only in development" do
    bootstrap_session
    assert_nil json["settings"]["dev_credentials"], "test and production must not expose demo passwords"

    with_rails_env("development") do
      bootstrap_session
      dev = json["settings"]["dev_credentials"]
      assert dev.present?
      assert_equal false, dev["forced"], "in development the shortcuts are normal, not a warning"
      assert_equal [ "cliente@printremeras.local" ], dev["customers"].map { |c| c["email"] }
      assert_equal [ "cliente@printremeras.local" ], dev["customers"].map { |c| c["email"] }
      assert dev["staff"].any? { |s| s["label"] == "admin" }
    end
  end

  test "HIDE_DEV_CREDENTIALS switches the shortcuts off while still in development" do
    with_rails_env("development") do
      assert DevCredentials.enabled?
      ENV["HIDE_DEV_CREDENTIALS"] = "true"
      assert_not DevCredentials.enabled?
      assert_empty DevCredentials.staff_list
      assert_empty DevCredentials.customer_list
    end
  ensure
    ENV.delete("HIDE_DEV_CREDENTIALS")
  end

  test "the admin sign-in page lists the shortcuts in development and hides them otherwise" do
    get "/admin/session/new"
    assert_response :success
    assert_no_match "changeme-admin-1", response.body

    with_rails_env("development") do
      get "/admin/session/new"
      assert_response :success
      assert_match DevCredentials.admin[:email], response.body
      assert_match DevCredentials.admin[:password], response.body
      assert_match "dev-cred", response.body
    end
  end

  test "a production container can opt in explicitly and is warned about it" do
    bootstrap_session
    assert_nil json["settings"]["dev_credentials"]

    ENV["SHOW_DEV_CREDENTIALS"] = "true"
    assert DevCredentials.enabled?
    assert DevCredentials.forced?, "outside development the shortcuts must announce themselves"
    bootstrap_session
    assert json["settings"]["dev_credentials"]["forced"]

    get "/admin/session/new"
    assert_match DevCredentials.admin[:password], response.body
    assert_match I18n.t("admin.auth.dev_accounts_forced", env: Rails.env), response.body
  ensure
    ENV.delete("SHOW_DEV_CREDENTIALS")
  end

  test "hiding always wins over the opt-in" do
    ENV["SHOW_DEV_CREDENTIALS"] = "true"
    ENV["HIDE_DEV_CREDENTIALS"] = "true"
    assert_not DevCredentials.enabled?
  ensure
    ENV.delete("SHOW_DEV_CREDENTIALS")
    ENV.delete("HIDE_DEV_CREDENTIALS")
  end

  test "the advertised admin password actually signs in" do
    creds = DevCredentials.admin
    AdminUser.create!(email: creds[:email], password: creds[:password], name: creds[:name], role: "admin")
    post "/admin/session", params: { email: creds[:email], password: creds[:password] }
    assert_redirected_to "/admin"
  end

  test "staff accounts are kept out of the customer sign-in shortcuts" do
    with_rails_env("development") do
      creds = DevCredentials.admin
      AdminUser.create!(email: creds[:email], password: creds[:password], name: creds[:name], role: "admin")
      bootstrap_session
      customer_emails = json["settings"]["dev_credentials"]["customers"].map { |c| c["email"] }
      assert_not_includes customer_emails, creds[:email],
                          "an AdminUser cannot sign in on the storefront, so offering it there would always fail"

      # Prove the reason: the storefront rejects admin credentials outright.
      api :post, "/api/v1/session", { email: creds[:email], password: creds[:password] }
      assert_response :unauthorized
    end
  end

  test "the admin sign-in page offers a password visibility toggle" do
    get "/admin/session/new"
    assert_response :success
    assert_match "toggle-password", response.body
    assert_match I18n.t("admin.auth.show_password"), response.body
  end

  test "the advertised customer password actually signs in" do
    account = DevCredentials::CUSTOMER
    User.create!(email: account[:email], password: account[:password], first_name: account[:first_name], confirmed_at: Time.current)
    bootstrap_session
    api :post, "/api/v1/session", { email: account[:email], password: account[:password] }
    assert_response :success, response.body
    assert_equal account[:email], json["user"]["email"]
  end
end
