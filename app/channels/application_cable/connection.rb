module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_admin

    def connect
      self.current_user = User.find_by(id: request.session[:user_id])
      self.current_admin = AdminUser.active.find_by(id: request.session[:admin_user_id])
      reject_unauthorized_connection unless current_user || current_admin
    end
  end
end
