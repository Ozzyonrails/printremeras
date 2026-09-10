module Rendering
  class RenderOrderItem < ApplicationService
    def initialize(order_item:, preview_renderer: Adapters.preview_renderer, print_renderer: Adapters.print_file_renderer)
      @item = order_item
      @preview_renderer = preview_renderer
      @print_renderer = print_renderer
    end

    def call
      placements = @item.placements.includes(:design, :print_area)
      placements = @item.catalog_item.placements.includes(:design, :print_area) if placements.empty? && @item.catalog_item
      return success(skipped: true) if placements.empty?

      by_area = placements.group_by(&:print_area)
      @item.print_files.purge if @item.print_files.attached?
      by_area.each do |area, group|
        out = @print_renderer.render(print_area: area, placements: group)
        @item.print_files.attach(io: File.open(out.file.path), filename: "#{@item.order.number}-item#{@item.id}-#{area.side}.#{out.extension}", content_type: out.content_type)
        out.file.close!
      end
      front = by_area.keys.detect { |a| a.side == "front" } || by_area.keys.first
      if front.mockup.attached?
        out = @preview_renderer.render(print_area: front, placements: by_area[front])
        @item.preview.attach(io: File.open(out.file.path), filename: "#{@item.order.number}-item#{@item.id}-preview.#{out.extension}", content_type: out.content_type)
        out.file.close!
      end
      success(order_item: @item)
    end
  end
end
