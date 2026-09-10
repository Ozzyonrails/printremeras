module Identity
  class ConfirmEmail < ApplicationService
    def initialize(token:)
      @token = token
    end

    def call
      user = User.find_by_token_for(:email_confirmation, @token.to_s)
      return failure([ I18n.t("identity.invalid_token") ], code: :invalid) unless user

      user.confirm!
      success(user: user)
    end
  end
end
