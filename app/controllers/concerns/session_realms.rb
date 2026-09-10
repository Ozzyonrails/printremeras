# Customers and staff share one session cookie, so a plain reset_session on either sign-in
# would silently sign the other realm out and invalidate the CSRF token of any page it had
# open. Rotating the session still protects against fixation; the other realm's key is
# simply carried across.
module SessionRealms
  extend ActiveSupport::Concern

  private

  def reset_session_preserving(*keys)
    kept = keys.to_h { |key| [ key, session[key] ] }.compact
    reset_session
    kept.each { |key, value| session[key] = value }
  end
end
