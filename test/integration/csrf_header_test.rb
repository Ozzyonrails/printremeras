require "test_helper"

# A browser that sends two CSRF tokens in one header (which XMLHttpRequest produces when
# the header is set twice) must be rejected — that is correct Rails behaviour, and it is
# what broke admin uploads until the client stopped adding a duplicate header.
class CsrfHeaderTest < ActionDispatch::IntegrationTest
  setup do
    @template = create_template
    ActionController::Base.allow_forgery_protection = true
  end

  teardown { ActionController::Base.allow_forgery_protection = false }

  test "one token is accepted, the same token sent twice is refused" do
    get "/api/v1/session", headers: { "Accept" => "application/json" }
    token = JSON.parse(response.body)["csrf_token"]
    body = { blob: { filename: "a.png", byte_size: 1024, checksum: "abc==", content_type: "image/png" } }.to_json
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }

    post "/api/v1/uploads", params: body, headers: headers.merge("X-CSRF-Token" => token)
    assert_response :success

    get "/api/v1/session", headers: { "Accept" => "application/json" }
    second = JSON.parse(response.body)["csrf_token"]
    post "/api/v1/uploads", params: body, headers: headers.merge("X-CSRF-Token" => "#{token}, #{second}")
    assert_response :unprocessable_content
    assert_equal "invalid_csrf_token", JSON.parse(response.body)["error"]
  end
end
