require "test_helper"

# A blob row is written before its bytes are uploaded, so a storage failure can leave a
# record pointing at nothing. The admin must be told to re-upload, not shown a broken image.
class MissingMockupTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
    @template = create_template
  end

  test "a photo whose object vanished is reported instead of rendered" do
    area = @template.front_area
    assert area.mockup_available?

    area.mockup.blob.service.delete(area.mockup.blob.key)
    area.reload

    get "/admin/templates/#{@template.id}"
    assert_response :success
    assert_match I18n.t("admin.templates.mockup_missing"), response.body
    assert_no_match(/data-react="print-area-editor"[^>]*area-#{area.side}/, response.body)
  end

  test "an intact photo still renders the rectangle editor" do
    get "/admin/templates/#{@template.id}"
    assert_response :success
    assert_no_match I18n.t("admin.templates.mockup_missing"), response.body
    assert_match 'data-react="print-area-editor"', response.body
  end
end
