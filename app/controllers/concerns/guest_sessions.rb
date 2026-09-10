# Issues and reads the httpOnly guest_token cookie (§4).
module GuestSessions
  extend ActiveSupport::Concern

  COOKIE = :guest_token

  private

  def current_guest_session
    return @current_guest_session if defined?(@current_guest_session)
    token = cookies.signed[COOKIE]
    @current_guest_session = token.present? ? GuestSession.unmerged.find_by(token: token) : nil
    @current_guest_session = nil if @current_guest_session&.expired?
    @current_guest_session&.touch_seen!
    @current_guest_session
  end

  def ensure_guest_session!
    current_guest_session || issue_guest_session!
  end

  def issue_guest_session!
    @current_guest_session = GuestSession.issue!
    cookies.signed[COOKIE] = { value: @current_guest_session.token, expires: GuestSession::LIFETIME.from_now, httponly: true, same_site: :lax, secure: request.ssl? }
    @current_guest_session
  end

  def clear_guest_session!
    cookies.delete(COOKIE)
    @current_guest_session = nil
  end
end
