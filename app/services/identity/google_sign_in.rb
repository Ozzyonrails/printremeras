module Identity
  class GoogleSignIn < ApplicationService
    def initialize(auth:, guest_session: nil, locale: nil)
      @auth = auth
      @guest = guest_session
      @locale = locale
    end

    def call
      info = @auth["info"] || {}
      uid = @auth["uid"].to_s
      email = info["email"].to_s.downcase
      return failure([ "Google account has no email" ], code: :invalid) if email.blank?

      user = User.find_by(google_uid: uid) || User.find_by(email: email)
      if user
        user.update!(google_uid: uid, confirmed_at: user.confirmed_at || Time.current, last_sign_in_at: Time.current)
      else
        user = User.create!(email: email, google_uid: uid, first_name: info["first_name"].to_s, last_name: info["last_name"].to_s,
                            confirmed_at: Time.current, locale: @locale.presence || I18n.locale.to_s, last_sign_in_at: Time.current)
      end
      Identity::MergeGuest.call(user: user, guest_session: @guest)
      success(user: user)
    end
  end
end
