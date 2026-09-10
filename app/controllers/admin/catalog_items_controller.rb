module Admin
  class CatalogItemsController < BaseController
    before_action :require_admin_role!
    before_action :load_item, only: %i[show edit update destroy editor publish]

    def index
      @items = CatalogItem.ordered.includes(:template, preview_attachment: :blob)
    end

    def show = redirect_to(editor_admin_catalog_item_path(@item))

    def new
      @item = CatalogItem.new(template_id: params[:template_id])
      @templates = Template.ordered
    end

    def create
      @item = CatalogItem.new(item_params)
      result = Catalog::SaveCatalogItem.call(catalog_item: @item, attributes: {}, placements: nil, admin_user: current_admin)
      if result.success?
        redirect_to editor_admin_catalog_item_path(@item), notice: t("admin.catalog.created_next_editor")
      else
        @templates = Template.ordered
        flash.now[:alert] = result.error_message
        render :new, status: :unprocessable_content
      end
    end

    def edit = @templates = Template.ordered

    # Handles both the HTML form (attributes) and the JSON save from the editor (placements).
    def update
      if request.format.json?
        result = Catalog::SaveCatalogItem.call(catalog_item: @item, attributes: {}, placements: params[:placements].to_a.map(&:to_unsafe_h), admin_user: current_admin)
        result.success? ? render(json: { ok: true }) : render(json: { error: result.error_message, errors: result.errors }, status: :unprocessable_content)
      else
        result = Catalog::SaveCatalogItem.call(catalog_item: @item, attributes: item_params, placements: nil, admin_user: current_admin)
        if result.success?
          redirect_to editor_admin_catalog_item_path(@item), notice: t("admin.saved")
        else
          @templates = Template.ordered
          flash.now[:alert] = result.error_message
          render :edit, status: :unprocessable_content
        end
      end
    end

    def editor
      @template = @item.template
      @props = {
        template: Serializers.template(@template, full: true),
        placements: @item.placements.includes(:design, :print_area).map { |p| Serializers.placement(p) },
        designs: Design.catalog.with_attached_file.order(created_at: :desc).limit(200).map { |d| Serializers.design(d) },
        saveUrl: admin_catalog_item_path(@item, format: :json), csrfToken: form_authenticity_token,
        uploadUrl: api_v1_uploads_path, designCreateUrl: admin_designs_path
      }
    end

    def publish
      publishing = params[:published] == "1"
      if publishing
        @item.placements.reload
        return redirect_to(editor_admin_catalog_item_path(@item), alert: t("admin.catalog.no_placements")) if @item.placements.empty?
      end
      @item.update!(published: publishing)
      audit!("catalog_item.published_changed", @item, { "published" => publishing })
      redirect_to admin_catalog_items_path, notice: t("admin.saved")
    end

    def destroy
      @item.destroy!
      redirect_to admin_catalog_items_path, notice: t("admin.deleted")
    end

    private

    def load_item = @item = CatalogItem.find(params[:id])

    def item_params
      params.require(:catalog_item).permit(:template_id, :slug, :price_cents, :position, :tags_string, title_translations: I18n.available_locales, description_translations: I18n.available_locales).to_h.tap do |h|
        h[:tags] = h.delete(:tags_string).to_s.split(",").map { |t| t.strip.downcase }.reject(&:blank?).uniq if h.key?(:tags_string)
      end
    end
  end
end
