module Admin
  class CustomersController < BaseController
    def index
      scope = User.order(created_at: :desc)
      scope = scope.where("email ILIKE :q OR first_name ILIKE :q OR last_name ILIKE :q", q: "%#{params[:q].strip}%") if params[:q].present?
      @users = paginate(scope)
    end

    def show
      @user = User.find(params[:id])
      @orders = @user.orders.placed.recent
      @conversation = Conversation.find_by(user: @user)
      @coupons = @user.coupons.order(created_at: :desc)
    end
  end
end
