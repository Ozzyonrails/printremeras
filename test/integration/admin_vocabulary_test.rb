require "test_helper"

class AdminVocabularyTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
  end

  test "the help page explains the vocabulary and links into both flows" do
    get "/admin/help"
    assert_response :success
    assert_match I18n.t("admin.help.template_title"), response.body
    assert_match I18n.t("admin.help.product_title"), response.body
    assert_match new_admin_template_path, response.body
    assert_match new_admin_catalog_item_path, response.body
  end

  test "the garment form offers a colour palette and no prices on creation" do
    get "/admin/templates/new"
    assert_response :success
    assert_match(/<select[^>]*name="template\[color_hex\]"/, response.body)
    Template::PALETTE.each_key { |key| assert_match I18n.t("colors.#{key}"), response.body }
    assert_no_match(/name="template\[base_price_cents\]"/, response.body)
    assert_no_match(/name="template\[position\]"/, response.body)
  end

  test "prices appear once the garment exists" do
    template = create_template
    get "/admin/templates/#{template.id}/edit"
    assert_response :success
    assert_match(/name="template\[base_price_cents\]"/, response.body)
  end

  test "a garment saves without a colour name and shows the palette name instead" do
    post "/admin/templates", params: { template: {
      kind: "hoodie", color_hex: "#111111", color_name: "",
      name_translations: { I18n.default_locale.to_s => "Худи чёрное" } } }
    template = Template.order(:id).last
    assert_equal "", template.color_name.to_s
    I18n.with_locale(:ru) { assert_equal "Чёрный", template.color_label }
    I18n.with_locale(:es) { assert_equal "Negro", template.color_label }
  end

  test "lists carry a whole-row link so a tap anywhere opens the record" do
    template = create_template
    get "/admin/templates"
    assert_match "data-href=\"#{admin_template_path(template)}\"", response.body
  end
end
