require "test_helper"

# Shop owners should not have to think about slugs or maintain the same name twice.
class AdminFormSimplificationTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
  end

  test "the garment form asks for one name and no slug" do
    get "/admin/templates/new"
    assert_response :success
    assert_no_match(/name="template\[slug\]"/, response.body)
    names = response.body.scan(/name="template\[name_translations\]\[(\w+)\]"/).flatten
    assert_equal [ I18n.default_locale.to_s ], names, "one name field, not one per language"
  end

  test "a garment named in Russian gets a readable slug on its own" do
    post "/admin/templates", params: {
      template: { kind: "t-shirt", color_name: "Белый", color_hex: "#ffffff",
                  name_translations: { I18n.default_locale.to_s => "Футболка белая" } },
      front_mockup: fixture_file_upload(png_file(600, 700, name: "m.png").path, "image/png") }
    template = Template.order(:id).last
    assert_equal "futbolka-belaya", template.slug
    assert_redirected_to admin_template_path(template)
  end

  test "two garments with the same name do not collide" do
    2.times do
      post "/admin/templates", params: {
        template: { kind: "t-shirt", color_name: "Blanco", color_hex: "#ffffff",
                    name_translations: { I18n.default_locale.to_s => "Remera" } },
        front_mockup: fixture_file_upload(png_file(600, 700, name: "m.png").path, "image/png") }
    end
    assert_equal %w[remera remera-1], Template.order(:id).last(2).map(&:slug)
  end

  test "the product form asks for one title and no slug" do
    create_template
    get "/admin/catalog_items/new"
    assert_response :success
    assert_no_match(/name="catalog_item\[slug\]"/, response.body)
    titles = response.body.scan(/name="catalog_item\[title_translations\]\[(\w+)\]"/).flatten
    assert_equal [ I18n.default_locale.to_s ], titles
  end

  test "the admin chrome names itself and links to the shop" do
    get "/admin"
    assert_response :success
    assert_match I18n.t("admin.panel"), response.body
    assert_match I18n.t("admin.open_store"), response.body
    assert_match Rails.configuration.x.app.public_url, response.body
  end
end
