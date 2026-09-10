require "test_helper"

class PlacementTest < ActiveSupport::TestCase
  setup do
    @template = create_template
    @area = @template.front_area
    @guest = GuestSession.issue!
    @design = create_design(owner: @guest, width: 2000, height: 1000) # 2:1 landscape
  end

  test "artwork inside the area is valid and reports dpi" do
    p = Placement.new(design: @design, print_area: @area, placeable: Cart.create!(owner: @guest), x: 0.5, y: 0.5, scale: 0.5, rotation: 0)
    assert p.valid?, p.errors.full_messages.join
    assert_in_delta 140, p.artwork_width_mm, 0.01
    assert_in_delta 70, p.artwork_height_mm, 0.01
    assert_in_delta 2000 / (140 / 25.4), p.effective_dpi, 0.5
  end

  test "artwork escaping the area is rejected" do
    p = Placement.new(design: @design, print_area: @area, placeable: Cart.create!(owner: @guest), x: 0.9, y: 0.5, scale: 0.5)
    assert_not p.valid?
    assert p.errors.added?(:base, :outside_print_area)
  end

  test "rotation enlarges the bounding box" do
    p = Placement.new(design: @design, print_area: @area, placeable: Cart.create!(owner: @guest), x: 0.5, y: 0.5, scale: 0.98, rotation: 45)
    assert_not p.within_area?
    p.rotation = 0
    assert p.within_area?
  end

  test "low dpi is accepted and flagged rather than rejected" do
    small = create_design(owner: @guest, width: 800, height: 800)
    p = Placement.new(design: small, print_area: @area, placeable: Cart.create!(owner: @guest), x: 0.5, y: 0.5, scale: 1.0)
    assert p.valid?, p.errors.full_messages.join
    assert p.low_quality?
    assert_operator p.required_width_px, :>, small.width_px
  end

  test "low dpi can still be enforced when the shop opts in" do
    Setting.set(:enforce_min_dpi, true)
    small = create_design(owner: @guest, width: 800, height: 800)
    p = Placement.new(design: small, print_area: @area, placeable: Cart.create!(owner: @guest), x: 0.5, y: 0.5, scale: 1.0)
    assert_not p.valid?
    assert p.errors.added?(:base, :low_dpi)
  ensure
    Setting.set(:enforce_min_dpi, false)
  end

  test "an enhanced design raises the effective dpi" do
    small = create_design(owner: @guest, width: 800, height: 800)
    p = Placement.create!(design: small, print_area: @area, placeable: Cart.create!(owner: @guest), x: 0.5, y: 0.5, scale: 1.0)
    assert p.low_quality?

    small.enhanced_file.attach(upload_blob(png_file(3000, 3000)))
    small.update!(enhancement_status: "done", enhanced_width_px: 3000, enhanced_height_px: 3000, enhanced_at: Time.current)
    assert_not p.reload.low_quality?
    assert_equal 3000, small.effective_width_px
  end
end
