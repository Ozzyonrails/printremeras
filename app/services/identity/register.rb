module Identity
  class Register < ApplicationService
    def initialize(email:, password:, first_name: nil, last_name: nil, locale: nil, guest_session: nil)
      @attrs = { email: email, password: password, first_name: first_name.to_s, last_name: last_name.to_s, locale: locale.presence || I18n.locale.to_s }
      @guest = guest_session
    end

    def call
      user = User.new(@attrs)
      return failure(user.errors.full_messages, code: :invalid) unless user.save

      Identity::MergeGuest.call(user: user, guest_session: @guest)
      Identity::AccountMailer.with(user: user, token: user.generate_token_for(:email_confirmation)).confirmation.deliver_later
      success(user: user)
    end
  end
end
