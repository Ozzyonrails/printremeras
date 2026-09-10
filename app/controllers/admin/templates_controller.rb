module Admin
  class TemplatesController < BaseController
    before_action :require_admin_role!
    before_action :load_template, only: %i[show edit update destroy]

    def index
      @templates = Template.ordered.includes(:template_sizes, print_areas: { mockup_attachment: :blob })
    end

    def show
      @print_areas = PrintArea::SIDES.map { |side| @template.print_area(side) || @template.print_areas.build(side: side) }
      @sizes = @template.template_sizes
    end

    def new = @template = Template.new(kind: "t-shirt", color_hex: "#ffffff")

    def create
      @template = Template.new(template_params)
      if @template.save
        audit!("template.created", @template, @template.attributes.slice("slug", "base_price_cents", "print_price_one_side_cents", "print_price_two_sides_cents"))
        redirect_to admin_template_path(@template), notice: t("admin.saved")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      @template.assign_attributes(template_params)
      price_changes = @template.changes.slice("base_price_cents", "print_price_one_side_cents", "print_price_two_sides_cents")
      if @template.save
        audit!("template.price_changed", @template, price_changes) if price_changes.any?
        audit!("template.updated", @template, @template.saved_changes.except("updated_at"))
        redirect_to admin_template_path(@template), notice: t("admin.saved")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @template.destroy
        redirect_to admin_templates_path, notice: t("admin.deleted")
      else
        redirect_to admin_template_path(@template), alert: @template.errors.full_messages.join(", ")
      end
    end

    private

    def load_template = @template = Template.find(params[:id])

    def template_params
      p = params.require(:template).permit(:kind, :slug, :color_name, :color_hex, :base_price_cents, :print_price_one_side_cents, :print_price_two_sides_cents, :active, :position,
                                           name_translations: I18n.available_locales, description_translations: I18n.available_locales)
      p
    end
  end
end
