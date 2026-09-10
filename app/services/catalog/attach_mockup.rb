module Catalog
  # Attaches a garment photo to a print area and records its pixel size, which the admin
  # editor needs to warn when the drawn rectangle's proportions drift from the physical
  # millimetres. Shared by the template form and the print-area form.
  class AttachMockup < ApplicationService
    def initialize(print_area:, file:)
      @print_area = print_area
      @file = file
    end

    def call
      return success(attached: false) if @file.blank?
      # A form submitted without multipart delivers the filename as a String, which used to
      # blow up deep inside the image probe. Fail with something a human can act on.
      return failure([ I18n.t("admin.templates.mockup_not_a_file") ], code: :invalid) unless @file.respond_to?(:tempfile)

      require "vips"
      image = Vips::Image.new_from_file(@file.tempfile.path, access: :sequential)
      @print_area.mockup.attach(@file)
      @print_area.mockup_width_px = image.width
      @print_area.mockup_height_px = image.height

      # On a new record Active Storage defers the upload until save, so the object only
      # exists afterwards. Save first, then confirm the bytes really landed: the blob row is
      # written before the upload, and a storage failure used to leave a record pointing at
      # nothing while the admin saw a broken image.
      @print_area.save
      if @print_area.persisted?
        blob = @print_area.mockup.blob
        unless blob.service.exist?(blob.key)
          return failure([ I18n.t("admin.templates.mockup_not_stored") ], code: :storage)
        end
      end

      success(attached: true, width: image.width, height: image.height)
    rescue Vips::Error => e
      failure([ I18n.t("admin.templates.mockup_unreadable", message: e.message.to_s.lines.first.to_s.strip) ], code: :invalid)
    end
  end
end
