module Catalog
  # Turns raw placement params into validated Placement records for a placeable
  # (CartItem, OrderItem, CatalogItem). Ownership of designs is enforced so a client
  # cannot reference another customer's upload. Returns unsaved records; the caller
  # persists them inside its own transaction.
  class BuildPlacements < ApplicationService
    def initialize(template:, placements:, owner:, placeable: nil, allow_catalog_designs: true)
      @template = template
      @params = Array(placements)
      @owner = owner
      @placeable = placeable
      @allow_catalog_designs = allow_catalog_designs
    end

    def call
      return failure([ I18n.t("placements.errors.none") ]) if @params.empty?

      areas = @template.print_areas.index_by(&:id)
      records = []
      errors = []
      seen_sides = Set.new

      @params.each do |raw|
        p = (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h).with_indifferent_access
        area = areas[p[:print_area_id].to_i]
        next errors << I18n.t("placements.errors.unknown_area") unless area
        next errors << I18n.t("placements.errors.duplicate_side", side: area.side) unless seen_sides.add?(area.id)

        design = Design.find_by(id: p[:design_id])
        next errors << I18n.t("placements.errors.unknown_design") unless design
        unless design.owned_by?(@owner) || (@allow_catalog_designs && design.catalog?) || admin_owner?
          next errors << I18n.t("placements.errors.unknown_design")
        end

        placement = Placement.new(design: design, print_area: area, placeable: @placeable,
                                  x: p.fetch(:x, 0.5), y: p.fetch(:y, 0.5), scale: p.fetch(:scale, 0.5), rotation: p.fetch(:rotation, 0))
        placement.validate
        placement.errors.delete(:placeable) if @placeable.nil?
        if placement.errors.any?
          errors.concat(placement.errors.full_messages.map { |m| "#{area.side}: #{m}" })
        else
          records << placement
        end
      end

      errors.any? ? failure(errors, code: :invalid) : success(placements: records)
    end

    private

    def admin_owner? = @owner.is_a?(AdminUser)
  end
end
