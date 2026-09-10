module Admin
  class TemplateSizesController < BaseController
    before_action :require_admin_role!
    before_action { @template = Template.find(params[:template_id]) }

    def create
      size = @template.template_sizes.build(size_params)
      if size.save
        audit!("stock.adjusted", size, { "label" => size.label, "stock" => size.stock })
        redirect_to admin_template_path(@template, anchor: "sizes"), notice: t("admin.saved")
      else
        redirect_to admin_template_path(@template, anchor: "sizes"), alert: size.errors.full_messages.join(", ")
      end
    end

    def update
      size = @template.template_sizes.find(params[:id])
      size.assign_attributes(size_params)
      changes = size.changes.slice("stock", "restock_at", "label")
      if size.save
        audit!("stock.adjusted", size, changes) if changes.any?
        redirect_to admin_template_path(@template, anchor: "sizes"), notice: t("admin.saved")
      else
        redirect_to admin_template_path(@template, anchor: "sizes"), alert: size.errors.full_messages.join(", ")
      end
    end

    def destroy
      size = @template.template_sizes.find(params[:id])
      size.destroy ? redirect_to(admin_template_path(@template, anchor: "sizes"), notice: t("admin.deleted")) : redirect_to(admin_template_path(@template), alert: size.errors.full_messages.join(", "))
    end

    private

    def size_params = params.require(:template_size).permit(:label, :stock, :restock_at, :position)
  end
end
