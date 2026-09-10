require "test_helper"

# Creating a product should be one step: pick the garment, name it, price it, upload the
# artwork. The editor is for nudging afterwards, not for finding the upload button.
class ProductCreationTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
    @template = create_template
  end

  def create_product(file: png_file(1800, 1800, name: "art.png"), price: 1_400_000)
    post "/admin/catalog_items", params: {
      catalog_item: { template_id: @template.id, price_cents: price,
                      title_translations: { I18n.default_locale.to_s => "Принт один" } },
      design_file: file && fixture_file_upload(file.path, "image/png")
    }
  end

  test "the form takes the artwork and is multipart" do
    get "/admin/catalog_items/new"
    assert_response :success
    assert_match(/<form[^>]*enctype="multipart\/form-data"/, response.body)
    assert_match(/name="design_file"/, response.body)
  end

  test "a product is created with the design already placed" do
    create_product
    item = CatalogItem.order(:id).last
    assert_redirected_to editor_admin_catalog_item_path(item)

    assert_equal 1, item.placements.count
    placement = item.placements.first
    assert_equal @template.front_area, placement.print_area
    assert_equal "catalog", placement.design.source
    assert placement.design.file.attached?
    assert_in_delta 0.5, placement.x.to_f, 0.001, "centred horizontally"
    assert placement.within_area?, "and sitting inside the print area"
  end

  test "a tall design is scaled down so it still fits the area" do
    create_product(file: png_file(800, 2400, name: "tall.png"))
    placement = CatalogItem.order(:id).last.placements.first
    assert placement.within_area?
    assert_operator placement.scale.to_f, :<, 0.6
  end

  test "a garment with no print area is reported instead of failing silently" do
    bare = Template.create!(kind: "t-shirt", color_hex: "#ffffff", color_name: "",
                            name_translations: { I18n.default_locale.to_s => "Голый" })
    post "/admin/catalog_items", params: {
      catalog_item: { template_id: bare.id, price_cents: 100,
                      title_translations: { I18n.default_locale.to_s => "Без зоны" } },
      design_file: fixture_file_upload(png_file(900, 900, name: "a.png").path, "image/png") }
    follow_redirect!
    assert_match I18n.t("admin.catalog.template_without_area"), response.body
  end
end
