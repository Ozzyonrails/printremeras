module Admin
  class SessionsController < BaseController
    include SessionRealms
    skip_before_action :require_admin!
    layout "admin_login"

    def new
      redirect_to admin_root_path if current_admin
    end

    def create
      admin = AdminUser.active.find_by(email: params[:email].to_s.downcase.strip)
      if admin&.authenticate(params[:password].to_s)
        reset_session_preserving(:user_id)
        session[:admin_user_id] = admin.id
        redirect_to session.delete(:admin_return_to) || admin_root_path
      else
        flash.now[:alert] = t("admin.auth.invalid")
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      reset_session_preserving(:user_id)
      redirect_to new_admin_session_path
    end
  end
end
