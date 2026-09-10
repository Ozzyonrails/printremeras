module Admin
  class ModerationController < BaseController
    def index
      scope = Order.where(status: "pending_approval").order(:placed_at).includes(:user, items: :template)
      scope = scope.where(low_quality_artwork: true) if params[:quality] == "low"
      @orders = scope
      @low_quality_count = Order.where(status: "pending_approval", low_quality_artwork: true).count
    end

    def show
      @order = Order.find_by!(number: params[:number])
      @items = @order.items.includes(:template, placements: [ :design, print_area: { mockup_attachment: :blob } ])
    end

    def approve
      order = Order.find_by!(number: params[:number])
      result = Orders::Approve.call(order: order, admin_user: current_admin)
      redirect_to admin_moderation_index_path, result.success? ? { notice: t("admin.moderation.approved", number: order.number) } : { alert: result.error_message }
    end

    def reject
      order = Order.find_by!(number: params[:number])
      result = Orders::Reject.call(order: order, admin_user: current_admin, reason: params[:reason])
      redirect_to result.success? ? admin_moderation_index_path : admin_moderation_path(order), result.success? ? { notice: t("admin.moderation.rejected", number: order.number) } : { alert: result.error_message }
    end
  end
end
