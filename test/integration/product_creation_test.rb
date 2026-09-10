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

  test "the product picture is composited immediately, without waiting for a worker" do
    # Customers see this picture in the catalogue; queuing it meant products showed the bare
    # garment until a background worker happened to be running.
    create_product
    item = CatalogItem.order(:id).last
    assert item.preview.attached?, "the composite must exist as soon as the product does"
    assert_operator item.preview.blob.byte_size, :>, 0
    assert_equal "image/jpeg", item.preview.blob.content_type
  end

  test "publishing repairs a product whose picture is missing" do
    create_product
    item = CatalogItem.order(:id).last
    item.preview.purge
    assert_not item.reload.preview.attached?

    post "/admin/catalog_items/#{item.id}/publish", params: { published: "1" }
    assert item.reload.preview.attached?, "publishing must not put a pictureless product on sale"
    assert item.published?
  end

  test "a tall design is scaled down so it still fits the area" do
    create_product(file: png_file(800, 2400, name: "tall.png"))
    placement = CatalogItem.order(:id).last.placements.first
    assert placement.within_area?
    assert_operator placement.scale.to_f, :<, 0.6
  end

  test "the storefront sends a colour label even when the shop left the name blank" do
    @template.update!(color_name: "", color_hex: "#ffffff")
    create_product
    item = CatalogItem.order(:id).last
    item.update!(published: true)
    get "/api/v1/catalog_items/#{item.slug}", headers: { "Accept" => "application/json" }
    assert_response :success
    template = JSON.parse(response.body)["catalog_item"]["template"]
    assert_equal "", template["color_name"].to_s
    assert template["color_label"].present?, "a blank name falls back to the palette name"
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
