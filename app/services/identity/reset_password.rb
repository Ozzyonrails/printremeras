module Identity
  class ResetPassword < ApplicationService
    def initialize(token:, password:)
      @token = token
      @password = password
    end

    def call
      user = User.find_by_token_for(:password_reset, @token.to_s)
      return failure([ I18n.t("identity.invalid_token") ], code: :invalid) unless user
      return failure(user.errors.full_messages) unless user.update(password: @password)

      success(user: user)
    end
  end
end
