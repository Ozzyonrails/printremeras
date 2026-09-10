module CustomerAuthentication
  extend ActiveSupport::Concern
  include GuestSessions
  include SessionRealms

  included do
    helper_method :current_user if respond_to?(:helper_method)
  end

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  def signed_in? = current_user.present?

  def sign_in!(user)
    reset_session_preserving(:admin_user_id)
    session[:user_id] = user.id
    @current_user = user
    clear_guest_session!
    Current.user = user
  end

  def sign_out!
    reset_session_preserving(:admin_user_id)
    @current_user = nil
  end

  # Designs and carts belong to the user when signed in, otherwise to the guest session.
  def current_owner
    current_user || ensure_guest_session!
  end

  def current_cart
    @current_cart ||= Cart.find_or_create_by!(owner: current_owner)
  end
end
