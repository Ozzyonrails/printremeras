module Identity
  class RequestPasswordReset < ApplicationService
    def initialize(email:)
      @email = email.to_s.strip.downcase
    end

    # Always succeeds so the endpoint cannot be used to enumerate accounts.
    def call
      if (user = User.find_by(email: @email)) && user.password_digest.present?
        Identity::AccountMailer.with(user: user, token: user.generate_token_for(:password_reset)).password_reset.deliver_later
      end
      success
    end
  end
end
