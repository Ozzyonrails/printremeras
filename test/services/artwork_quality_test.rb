require "test_helper"

# Bad artwork is never a blocker: it is accepted, marked, and can be upscaled later.
class ArtworkQualityTest < ActiveSupport::TestCase
  setup do
    @template = create_template
    @size = @template.template_sizes.first
    @guest = GuestSession.issue!
    @admin = create_admin
  end

  test "an image below the recommended size uploads and is marked for enhancement" do
    blob = upload_blob(png_file(300, 300))
    result = Catalog::CreateDesign.call(owner: @guest, signed_blob_id: blob.signed_id)
    assert result.success?, result.error_message
    assert_equal "needed", result.design.enhancement_status
    assert result.design.needs_enhancement?
    assert_match "300", result.design.enhancement_note
  end

  test "the same upload is refused only when the shop enables the limit" do
    Setting.set(:enforce_min_upload_px, true)
    blob = upload_blob(png_file(300, 300))
    result = Catalog::CreateDesign.call(owner: @guest, signed_blob_id: blob.signed_id)
    assert result.failure?
  ensure
    Setting.set(:enforce_min_upload_px, false)
  end

  test "an order with low resolution artwork is placed, flagged, and queued for enhancement" do
    design = create_design(owner: @guest, width: 500, height: 500)
    cart = Cart.create!(owner: @guest)
    added = Orders::AddToCart.call(cart: cart, owner: @guest, template_id: @template.id, template_size_id: @size.id,
                                   placements: [ placement_params(design, @template.front_area, scale: 1.0) ])
    assert added.success?, "low resolution artwork must not block the cart: #{added.error_message}"

    user = create_user
    Identity::MergeGuest.call(user: user, guest_session: @guest)
    created = Orders::Create.call(user: user, cart: user.cart, shipping_method: "pickup")
    assert created.success?, created.error_message
    assert created.order.low_quality_artwork, "the order must be marked so moderation can see it"
    assert_equal "needed", design.reload.enhancement_status
    assert_match(/dpi/i, design.enhancement_note)
  end

  test "requesting enhancement without a provider marks the design instead of failing" do
    design = create_design(owner: @guest, width: 400, height: 400)
    result = Designs::RequestEnhancement.call(design: design, admin_user: @admin)
    assert result.success?, result.error_message
    assert_equal false, result.queued
    assert_equal "requested", design.reload.enhancement_status
    assert AuditLog.exists?(action: "design.enhancement_requested")
  end

  test "a configured provider upscales the file and the design starts using it" do
    design = create_design(owner: @guest, width: 500, height: 500)
    placement = Placement.create!(design: design, print_area: @template.front_area, placeable: Cart.create!(owner: @guest),
                                  x: 0.5, y: 0.5, scale: 1.0, rotation: 0)
    assert placement.low_quality?

    result = Designs::Enhance.call(design: design, target_width_px: 1800, target_height_px: 1800,
                                   provider: ImageEnhancement::LocalUpscaleProvider.new)
    assert result.success?, result.error_message
    design.reload
    assert design.enhanced?
    assert_equal 1800, design.effective_width_px
    assert_equal design.enhanced_file.blob.id, design.print_ready_file.blob.id
    assert_not placement.reload.low_quality?
  end

  test "upscaling to the computed target is enough to clear the flag" do
    design = create_design(owner: @guest, width: 500, height: 500)
    placement = Placement.create!(design: design, print_area: @template.front_area, placeable: Cart.create!(owner: @guest),
                                  x: 0.5, y: 0.5, scale: 0.9, rotation: 0)
    flagged = Designs::FlagQuality.call(design: design)
    assert flagged.needed

    Designs::Enhance.call(design: design, target_width_px: flagged.target_width_px, target_height_px: flagged.target_height_px,
                          provider: ImageEnhancement::LocalUpscaleProvider.new)
    assert_not placement.reload.low_quality?, "the target must round up, or the artwork stays flagged after enhancement"
  end

  test "catalog artwork uploads and publishes without a licence note" do
    blob = upload_blob(png_file(1500, 1500))
    result = Catalog::CreateDesign.call(owner: nil, signed_blob_id: blob.signed_id, source: "catalog")
    assert result.success?, "a missing licence note must not block a catalog upload: #{result.error_message}"
    design = result.design
    assert_nil design.license_note

    item = CatalogItem.create!(template: @template, title_translations: { "es" => "Sin licencia" }, slug: "sin-licencia", price_cents: 900_000)
    item.placements.create!(design: design, print_area: @template.front_area, x: 0.5, y: 0.5, scale: 0.5, rotation: 0)
    assert item.valid?, item.errors.full_messages.join

    item.update!(published: true)
    assert item.reload.published?, "publishing must not depend on a licence note"
  end

  test "a design cannot claim to be enhanced without the improved file" do
    design = create_design(owner: @guest, width: 400, height: 400)
    design.enhancement_status = "done"
    assert_not design.valid?, "status must not say done while the enhanced file is missing"
    assert design.errors.added?(:enhanced_file, :blank)
  end

  test "print files are rendered from the enhanced file once it exists" do
    design = create_design(owner: @guest, width: 500, height: 500)
    Designs::Enhance.call(design: design, target_width_px: 1500, target_height_px: 1500,
                          provider: ImageEnhancement::LocalUpscaleProvider.new)
    user = create_user
    order = Order.create!(user: user, number: Order.generate_number, status: "paid", shipping_method: "pickup",
                          subtotal_cents: 100, total_cents: 100)
    item = order.items.create!(template: @template, template_size: @size, quantity: 1, unit_price_cents: 100,
                               line_total_cents: 100, snapshot: { "title" => "x", "size_label" => "M" })
    item.placements.create!(design: design.reload, print_area: @template.front_area, x: 0.5, y: 0.5, scale: 0.8, rotation: 0)

    assert Rendering::RenderOrderItem.call(order_item: item).success?
    assert item.reload.print_files.attached?
  end
end
