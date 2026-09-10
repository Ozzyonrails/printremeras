module Admin
  # Queue of artwork that is below the print-quality threshold. Nothing here blocked an
  # order; these are files worth upscaling before they go to the printer.
  class ArtworkController < BaseController
    def index
      status = Design::ENHANCEMENT_STATUSES.include?(params[:status]) ? params[:status] : nil
      scope = Design.with_attached_file.includes(placements: :print_area).order(created_at: :desc)
      scope = status ? scope.where(enhancement_status: status) : scope.needing_enhancement
      @status = status
      @designs = paginate(scope)
      @counts = Design.group(:enhancement_status).count
    end

    def enhance
      design = Design.find(params[:id])
      result = Designs::RequestEnhancement.call(design: design, admin_user: current_admin)
      redirect_back fallback_location: admin_artwork_index_path,
                    **(result.success? ? { notice: result.queued ? t("admin.artwork.queued") : t("admin.artwork.marked") } : { alert: result.error_message })
    end

    def dismiss
      design = Design.find(params[:id])
      design.update!(enhancement_status: "none", enhancement_note: nil)
      audit!("design.enhancement_dismissed", design)
      redirect_back fallback_location: admin_artwork_index_path, notice: t("admin.saved")
    end
  end
end
