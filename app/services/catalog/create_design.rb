module Catalog
  # Registers an uploaded file (already in the private bucket via direct upload) as a
  # Design. The real MIME type is sniffed from the bytes; dimensions come from libvips.
  class CreateDesign < ApplicationService
    def initialize(owner:, signed_blob_id:, source: "user", license_note: nil)
      @owner = owner
      @signed_blob_id = signed_blob_id
      @source = source
      @license_note = license_note
    end

    def call
      blob = ActiveStorage::Blob.find_signed(@signed_blob_id.to_s)
      return failure([ I18n.t("designs.errors.blob_not_found") ], code: :not_found) unless blob
      return failure([ I18n.t("designs.errors.too_large", mb: Setting.max_upload_bytes / 1.megabyte) ], code: :invalid) if blob.byte_size > Setting.max_upload_bytes

      probe = probe(blob)
      return failure(probe.errors, code: :invalid) if probe.failure?

      design = Design.new(owner: @owner, source: @source, license_note: @license_note, width_px: probe.width, height_px: probe.height,
                          content_type: probe.content_type, byte_size: blob.byte_size, original_filename: blob.filename.to_s,
                          moderation_status: "pending",
                          enhancement_status: probe.below_min_px ? "needed" : "none",
                          enhancement_note: probe.below_min_px ? I18n.t("designs.quality.below_min_px", px: Setting.min_upload_px, w: probe.width, h: probe.height) : nil)
      design.file.attach(blob)
      return failure(design.errors.full_messages) unless design.save

      blob.update!(content_type: probe.content_type) if blob.content_type != probe.content_type
      DomainEvents.publish(:design_uploaded, design_id: design.id)
      success(design: design)
    rescue Vips::Error
      failure([ I18n.t("designs.errors.unreadable") ], code: :invalid)
    end

    private

    def probe(blob)
      blob.open do |file|
        content_type = Marcel::MimeType.for(file, name: blob.filename.to_s)
        return failure([ I18n.t("designs.errors.unsupported_type") ]) unless Design::ALLOWED_TYPES.include?(content_type)

        image = Vips::Image.new_from_file(file.path, access: :sequential)
        width, height = image.width, image.height
        min_px = Setting.min_upload_px
        small = [ width, height ].min < min_px
        # Small artwork is accepted and flagged; only reject it when the shop opts in.
        return failure([ I18n.t("designs.errors.too_small", px: min_px) ]) if small && Setting.enforce_min_upload_px

        success(width: width, height: height, content_type: content_type, below_min_px: small)
      end
    end
  end
end
