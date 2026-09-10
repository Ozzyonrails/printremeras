module Identity
  class OmniauthCallbacksController < ApplicationController
    skip_before_action :verify_authenticity_token, only: :google

    def google
      result = Identity::GoogleSignIn.call(auth: request.env["omniauth.auth"].to_h, guest_session: current_guest_session, locale: I18n.locale.to_s)
      if result.success?
        sign_in!(result.user)
        redirect_to (request.env["omniauth.origin"].presence || "/").sub(%r{\Ahttps?://[^/]+}, "")
      else
        redirect_to "/login?error=google"
      end
    end

    def failure
      redirect_to "/login?error=google"
    end
  end
end
