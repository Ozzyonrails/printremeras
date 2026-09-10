module Api
  module V1
    class DesignsController < BaseController
      def index
        designs = Design.owned_by(current_owner).where(source: "user").with_attached_file.order(created_at: :desc).limit(50)
        render json: { designs: designs.map { |d| Serializers.design(d) } }
      end

      def create
        result = Catalog::CreateDesign.call(owner: current_owner, signed_blob_id: params.require(:signed_id))
        render_result(result) { |r| render json: { design: Serializers.design(r.design) }, status: :created }
      end

      def show
        design = Design.owned_by(current_owner).find(params[:id])
        render json: { design: Serializers.design(design) }
      end

      def destroy
        design = Design.owned_by(current_owner).find(params[:id])
        return render_errors([ I18n.t("designs.errors.in_use") ]) if design.placements.exists?
        design.destroy!
        head :no_content
      end

      # POST /api/v1/designs/validate_placement — server-side check the editor calls before add-to-cart
      def validate_placement
        template = Template.find(params.require(:template_id))
        result = Catalog::BuildPlacements.call(template: template, placements: params[:placements].presence || [ params.require(:placement) ], owner: current_owner)
        if result.success?
          # Low DPI is reported as a warning, not a rejection: the artwork is accepted and
          # flagged so it can be upscaled before printing.
          placements = result.placements.map do |p|
            { print_area_id: p.print_area_id, effective_dpi: p.effective_dpi.round, low_quality: p.low_quality?,
              min_dpi: p.print_area.effective_min_dpi, required_width_px: p.required_width_px, required_height_px: p.required_height_px }
          end
          render json: { valid: true, placements: placements, warnings: placements.select { |p| p[:low_quality] } }
        else
          render json: { valid: false, error: result.errors.first, errors: result.errors, code: "invalid" }, status: :unprocessable_content
        end
      end
    end
  end
end
