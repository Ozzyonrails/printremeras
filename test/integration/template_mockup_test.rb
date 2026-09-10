require "test_helper"

class TemplateMockupTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
  end

  test "a garment can be created with its photo in one step" do
    file = png_file(900, 1100, name: "mockup.png")
    post "/admin/templates", params: {
      template: { kind: "t-shirt", slug: "remera-uno", color_name: "Blanco", color_hex: "#ffffff",
                  base_price_cents: 1_200_000, print_price_one_side_cents: 600_000, print_price_two_sides_cents: 950_000,
                  active: "1", name_translations: { es: "Remera uno", ru: "Футболка один" } },
      front_mockup: fixture_file_upload(file.path, "image/png")
    }
    template = Template.find_by!(slug: "remera-uno")
    assert_redirected_to admin_template_path(template)

    area = template.print_areas.find_by(side: "front")
    assert area.present?, "the front print area must exist so the rectangle can be drawn"
    assert area.mockup.attached?
    assert_equal 900, area.mockup_width_px, "pixel size is recorded for the proportion warning"
    assert_equal 1100, area.mockup_height_px
  end

  test "creating without a photo still works and leaves the upload for later" do
    post "/admin/templates", params: {
      template: { kind: "t-shirt", slug: "remera-dos", color_name: "Negro", color_hex: "#111111",
                  base_price_cents: 1_000_000, print_price_one_side_cents: 500_000, print_price_two_sides_cents: 800_000,
                  name_translations: { es: "Remera dos" } }
    }
    template = Template.find_by!(slug: "remera-dos")
    assert_empty template.print_areas
    get admin_template_path(template)
    assert_response :success
  end
end
