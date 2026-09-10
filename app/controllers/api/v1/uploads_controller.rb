module Api
  module V1
    # Direct-to-bucket uploads (§3). Returns a signed PUT URL for the private bucket; the
    # browser uploads straight to storage and then sends the signed_id to /designs,
    # /orders/:n/review or /messages.
    class UploadsController < BaseController
      include ActiveStorage::SetCurrent
      ALLOWED = %w[image/png image/jpeg image/webp].freeze

      def create
        blob_params = params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type)
        return render_errors([ I18n.t("designs.errors.unsupported_type") ]) unless ALLOWED.include?(blob_params[:content_type])
        return render_errors([ I18n.t("designs.errors.too_large", mb: Setting.max_upload_bytes / 1.megabyte) ]) if blob_params[:byte_size].to_i > Setting.max_upload_bytes

        blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_params.to_h.symbolize_keys, service_name: ApplicationRecord.private_storage.to_s)
        render json: { signed_id: blob.signed_id, direct_upload: { url: blob.service_url_for_direct_upload, headers: blob.service_headers_for_direct_upload } }
      end
    end
  end
end
