module Admin
  class PrintAreasController < BaseController
    before_action :require_admin_role!
    before_action { @template = Template.find(params[:template_id]) }

    def create
      area = @template.print_areas.build(area_params)
      save(area)
    end

    def update
      area = @template.print_areas.find(params[:id])
      area.assign_attributes(area_params)
      save(area)
    end

    def destroy
      area = @template.print_areas.find(params[:id])
      if area.destroy
        redirect_to admin_template_path(@template), notice: t("admin.deleted")
      else
        redirect_to admin_template_path(@template), alert: area.errors.full_messages.join(", ")
      end
    end

    private

    def save(area)
      if params.dig(:print_area, :mockup).present?
        area.mockup.attach(params[:print_area][:mockup])
        probe_dimensions(area)
      end
      if area.save
        audit!("print_area.saved", area, area.saved_changes.except("updated_at"))
        redirect_to admin_template_path(@template, anchor: "area-#{area.side}"), notice: t("admin.saved")
      else
        redirect_to admin_template_path(@template), alert: area.errors.full_messages.join(", ")
      end
    end

    def probe_dimensions(area)
      file = params[:print_area][:mockup]
      image = Vips::Image.new_from_file(file.tempfile.path, access: :sequential)
      area.mockup_width_px = image.width
      area.mockup_height_px = image.height
    rescue Vips::Error
      area.errors.add(:mockup, :invalid)
    end

    def area_params
      params.require(:print_area).permit(:side, :x, :y, :w, :h, :width_mm, :height_mm, :min_dpi)
    end
  end
end
