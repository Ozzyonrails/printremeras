require "test_helper"

# The template selector used to borrow the "name" label, so on the new-product form the
# first field read "Название" while actually being an empty dropdown of garments.
class CatalogFormTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
  end

  test "with no garments the form explains what to do instead of showing an empty dropdown" do
    assert_equal 0, Template.count
    get "/admin/catalog_items/new"
    assert_response :success
    assert_match I18n.t("admin.catalog.no_templates"), response.body
    assert_match new_admin_template_path, response.body
    assert_no_match(/<select[^>]*catalog_item\[template_id\]/, response.body)
  end

  test "with garments the selector is labelled as the garment, not the title" do
    template = create_template
    get "/admin/catalog_items/new"
    assert_response :success
    assert_match(/<select[^>]*name="catalog_item\[template_id\]"/, response.body)
    assert_match template.color_name, response.body
    labels = response.body.scan(/<label[^>]*for="catalog_item_template_id"[^>]*>([^<]+)</).flatten
    assert_equal [ I18n.t("admin.catalog.template") ], labels
    assert_not_equal I18n.t("admin.templates.name"), labels.first
  end
end
