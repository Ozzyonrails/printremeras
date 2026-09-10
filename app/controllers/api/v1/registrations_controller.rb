module Api
  module V1
    class RegistrationsController < BaseController
      def create
        result = Identity::Register.call(email: params.require(:email), password: params.require(:password), first_name: params[:first_name],
                                         last_name: params[:last_name], locale: I18n.locale.to_s, guest_session: current_guest_session)
        render_result(result) do |r|
          sign_in!(r.user)
          render json: { user: Serializers.user(r.user), csrf_token: form_authenticity_token, cart_quantity: current_cart.total_quantity }, status: :created
        end
      end
    end
  end
end
