module Admin
  class AdminUsersController < BaseController
    before_action :require_admin_role!

    def index = @admin_users = AdminUser.order(:name)
    def new = @admin_user = AdminUser.new(role: "operator")

    def create
      @admin_user = AdminUser.new(admin_params)
      if @admin_user.save
        audit!("admin_user.created", @admin_user, { "email" => @admin_user.email, "role" => @admin_user.role })
        redirect_to admin_admin_users_path, notice: t("admin.saved")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit = @admin_user = AdminUser.find(params[:id])

    def update
      @admin_user = AdminUser.find(params[:id])
      attrs = admin_params
      attrs = attrs.except(:password) if attrs[:password].blank?
      if @admin_user.update(attrs)
        audit!("admin_user.updated", @admin_user, @admin_user.saved_changes.except("updated_at", "password_digest"))
        redirect_to admin_admin_users_path, notice: t("admin.saved")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def admin_params = params.require(:admin_user).permit(:email, :name, :role, :locale, :active, :password)
  end
end
