module Admin
  # Catalog artwork uploaded by staff from the admin editor (JSON).
  class DesignsController < BaseController
    before_action :require_admin_role!

    def create
      result = Catalog::CreateDesign.call(owner: nil, signed_blob_id: params.require(:signed_id), source: "catalog", license_note: params[:license_note])
      if result.success?
        result.design.update_columns(moderation_status: "approved")
        audit!("design.catalog_uploaded", result.design, { "license_note" => params[:license_note] })
        render json: { design: Serializers.design(result.design) }, status: :created
      else
        render json: { error: result.error_message, errors: result.errors }, status: :unprocessable_content
      end
    end
  end
end
