module Rendering
  # "Download all artwork" for an order: print files + original uploads as a zip.
  class ExportArtwork < ApplicationService
    def initialize(order:)
      @order = order
    end

    def call
      buffer = Zip::OutputStream.write_buffer do |zip|
        @order.items.each do |item|
          item.print_files.each do |f|
            zip.put_next_entry("print-files/#{f.filename}")
            f.download { |chunk| zip.write(chunk) }
          end
          item.placements.includes(:design, :print_area).each do |p|
            next unless p.design.file.attached?
            zip.put_next_entry("originals/item#{item.id}-#{p.print_area.side}-#{p.design.file.filename}")
            p.design.file.download { |chunk| zip.write(chunk) }
          end
        end
      end
      buffer.rewind
      success(io: buffer, filename: "#{@order.number}-artwork.zip")
    end
  end
end
