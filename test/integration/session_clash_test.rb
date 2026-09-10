require "test_helper"

# Staff and customers share one session cookie. Signing in on one side must not sign the
# other out, which used to happen and left an open admin page with a dead CSRF token.
class SessionClashTest < ActionDispatch::IntegrationTest
  test "signing in as a customer must not destroy an admin session" do
    admin = create_admin
    user = create_user
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
    get "/admin"
    assert_response :success, "admin is signed in"

    bootstrap_session
    api :post, "/api/v1/session", { email: user.email, password: "password123" }
    assert_response :success, "customer signed in"

    get "/admin"
    assert_response :success, "the admin session must survive a customer signing in on the storefront"

    get "/api/v1/orders", headers: { "Accept" => "application/json" }
    assert_response :success, "and the customer stays signed in too"
  end

  test "signing in as staff must not sign the customer out" do
    admin = create_admin
    user = create_user
    bootstrap_session
    api :post, "/api/v1/session", { email: user.email, password: "password123" }
    assert_response :success

    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
    assert_redirected_to "/admin"

    get "/api/v1/orders", headers: { "Accept" => "application/json" }
    assert_response :success, "the customer session must survive an admin signing in"
  end

  test "signing out of one realm leaves the other alone" do
    admin = create_admin
    user = create_user
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
    bootstrap_session
    api :post, "/api/v1/session", { email: user.email, password: "password123" }

    api :delete, "/api/v1/session"
    get "/admin"
    assert_response :success, "the customer signing out must not sign the admin out"

    delete "/admin/session"
    get "/api/v1/orders", headers: { "Accept" => "application/json" }
    assert_response :unauthorized, "and the admin signing out ends only the admin session"
  end
end
