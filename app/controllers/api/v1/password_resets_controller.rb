module Api
  module V1
    class PasswordResetsController < BaseController
      def create
        Identity::RequestPasswordReset.call(email: params.require(:email))
        render json: { ok: true }
      end

      def update
        result = Identity::ResetPassword.call(token: params[:token], password: params.require(:password))
        render_result(result) do |r|
          sign_in!(r.user)
          render json: { user: Serializers.user(r.user), csrf_token: form_authenticity_token }
        end
      end
    end
  end
end
