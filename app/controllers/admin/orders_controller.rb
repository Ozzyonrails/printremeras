module Admin
  class OrdersController < BaseController
    before_action :load_order, except: :index

    def index
      scope = Order.placed.recent.includes(:user, items: [ :template ])
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(shipping_method: params[:shipping]) if params[:shipping].present?
      if params[:q].present?
        q = "%#{params[:q].strip}%"
        scope = scope.joins(:user).where("orders.number ILIKE :q OR users.email ILIKE :q OR users.first_name ILIKE :q OR users.last_name ILIKE :q", q: q)
      end
      @orders = paginate(scope)
      @status_counts = Order.placed.group(:status).count
    end

    def show
      @items = @order.items.includes(:template, :template_size, :catalog_item, placements: [ :design, :print_area ])
      @next_states = Orders::Transition.next_states(@order)
      @conversation = Conversation.find_by(user_id: @order.user_id)
    end

    def transition
      result = Orders::Transition.call(order: @order, to: params[:to], actor: current_admin, reason: params[:reason].presence)
      redirect_to admin_order_path(@order), result.success? ? { notice: t("admin.orders.transitioned", status: t("orders.statuses.#{params[:to]}")) } : { alert: result.error_message }
    end

    def refund
      result = Payments::Refund.call(order: @order, admin_user: current_admin, reason: params[:reason].presence || "defect")
      redirect_to admin_order_path(@order), result.success? ? { notice: t("admin.orders.refunded") } : { alert: result.error_message }
    end

    def artwork
      result = Rendering::ExportArtwork.call(order: @order)
      send_data result.io.read, filename: result.filename, type: "application/zip"
    end

    def rerender
      @order.items.each { |i| Rendering::RenderOrderItemJob.perform_later(i.id) }
      redirect_to admin_order_path(@order), notice: t("admin.orders.rerender_queued")
    end

    private

    def load_order = @order = Order.find_by!(number: params[:number])
  end
end
