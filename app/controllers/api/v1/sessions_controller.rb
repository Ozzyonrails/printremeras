module Api
  module V1
    class SessionsController < BaseController
      # GET /api/v1/session — bootstrap payload for the SPA
      def show
        ensure_guest_session! unless signed_in?
        render json: { user: Serializers.user(current_user), locale: I18n.locale, cart_quantity: current_cart.total_quantity,
                       csrf_token: form_authenticity_token, settings: Serializers.public_settings,
                       unread_messages: current_user&.conversation&.unread_for_user || 0 }
      end

      def create
        result = Identity::Authenticate.call(email: params.require(:email), password: params.require(:password), guest_session: current_guest_session)
        render_result(result) do |r|
          sign_in!(r.user)
          render json: { user: Serializers.user(r.user), csrf_token: form_authenticity_token, cart_quantity: current_cart.total_quantity }
        end
      end

      def destroy
        sign_out!
        ensure_guest_session!
        render json: { ok: true, csrf_token: form_authenticity_token }
      end
    end
  end
end
