module Identity
  class Authenticate < ApplicationService
    def initialize(email:, password:, guest_session: nil)
      @email = email.to_s.strip.downcase
      @password = password.to_s
      @guest = guest_session
    end

    def call
      user = User.find_by(email: @email)
      return failure([ I18n.t("identity.invalid_credentials") ], code: :unauthorized) unless user&.password_digest && user.authenticate(@password)

      user.update_column(:last_sign_in_at, Time.current)
      Identity::MergeGuest.call(user: user, guest_session: @guest)
      success(user: user)
    end
  end
end
