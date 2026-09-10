module Admin
  class BaseController < ActionController::Base
    include LocaleResolution
    layout "admin"
    protect_from_forgery with: :exception
    before_action :require_admin!
    helper_method :current_admin, :admin?

    private

    def current_admin
      @current_admin ||= session[:admin_user_id] && AdminUser.active.find_by(id: session[:admin_user_id])
    end

    def admin? = current_admin&.admin?

    def require_admin!
      return if current_admin
      session[:admin_return_to] = request.fullpath if request.get?
      redirect_to new_admin_session_path, alert: t("admin.auth.sign_in_required")
    end

    def require_admin_role!
      redirect_to admin_root_path, alert: t("admin.auth.admin_only") unless admin?
    end

    def locale_preference = current_admin&.locale

    def audit!(action, subject, change_set = {})
      AuditLog.record!(action: action, admin_user: current_admin, subject: subject, change_set: change_set)
    end

    def page = [ params[:page].to_i, 1 ].max
    def per_page = 30
    def paginate(scope)
      @total = scope.count
      @pages = (@total / per_page.to_f).ceil
      scope.offset((page - 1) * per_page).limit(per_page)
    end
  end
end
