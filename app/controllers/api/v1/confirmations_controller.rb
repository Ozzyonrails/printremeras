module Api
  module V1
    class ConfirmationsController < BaseController
      def update
        result = Identity::ConfirmEmail.call(token: params[:token])
        render_result(result) { |r| render json: { user: Serializers.user(r.user) } }
      end

      def create
        return render_errors([ I18n.t("api.login_required") ], code: :unauthorized) unless signed_in?
        Identity::AccountMailer.with(user: current_user, token: current_user.generate_token_for(:email_confirmation)).confirmation.deliver_later unless current_user.confirmed?
        render json: { ok: true }
      end
    end
  end
end
