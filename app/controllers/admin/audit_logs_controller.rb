module Admin
  class AuditLogsController < BaseController
    before_action :require_admin_role!

    def index
      scope = AuditLog.recent.includes(:admin_user, :subject)
      scope = scope.where("action ILIKE ?", "%#{params[:q].strip}%") if params[:q].present?
      @logs = paginate(scope)
    end
  end
end
