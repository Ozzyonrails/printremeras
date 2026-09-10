require "test_helper"

class TemplateMockupTest < ActionDispatch::IntegrationTest
  setup do
    admin = create_admin
    post "/admin/session", params: { email: admin.email, password: "supersecret123" }
  end

  test "every form that takes a file is multipart" do
    # Integration tests post params directly, so a missing enctype slips past them: the
    # browser then sends the filename as a plain string and the upload blows up.
    get "/admin/templates/new"
    assert_match(/<form[^>]*enctype="multipart\/form-data"/, response.body,
                 "the creation form takes a photo, so it must be multipart")

    template = create_template
    get "/admin/templates/#{template.id}"
    assert_match(/<form[^>]*enctype="multipart\/form-data"/, response.body)
  end

  test "a filename arriving instead of a file is reported, not a 500" do
    template = create_template
    result = Catalog::AttachMockup.call(print_area: template.front_area, file: "IMG_0047.jpeg")
    assert result.failure?
    assert_equal I18n.t("admin.templates.mockup_not_a_file"), result.errors.first
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

  test "both sides can be uploaded at creation" do
    front = png_file(900, 1100, name: "front.png")
    back = png_file(900, 1100, name: "back.png")
    post "/admin/templates", params: {
      template: { kind: "t-shirt", color_hex: "#ffffff",
                  name_translations: { I18n.default_locale.to_s => "Двусторонняя" } },
      front_mockup: fixture_file_upload(front.path, "image/png"),
      back_mockup: fixture_file_upload(back.path, "image/png")
    }
    template = Template.find_by!(slug: "dvustoronnyaya")
    assert_equal %w[back front], template.print_areas.map(&:side).sort
    assert template.print_areas.all? { |a| a.mockup.attached? }
  end

  test "the front photo is required" do
    assert_no_difference -> { Template.count } do
      post "/admin/templates", params: { template: { kind: "t-shirt", color_hex: "#ffffff",
        name_translations: { I18n.default_locale.to_s => "Без фото" } } }
    end
    assert_response :unprocessable_content
    assert_match I18n.t("admin.templates.mockup_front_required"), response.body
  end

  test "the back side is optional" do
    front = png_file(900, 1100, name: "front.png")
    post "/admin/templates", params: {
      template: { kind: "t-shirt", color_hex: "#111111",
                  name_translations: { I18n.default_locale.to_s => "Только перед" } },
      front_mockup: fixture_file_upload(front.path, "image/png")
    }
    template = Template.order(:id).last
    assert_equal %w[front], template.print_areas.map(&:side)
    get admin_template_path(template)
    assert_response :success
  end
end
