module Api
  module V1
    class ProfileController < BaseController
      before_action :require_user!

      def update
        attrs = params.permit(:first_name, :last_name, :phone, :locale).to_h
        attrs[:locale] = nil unless I18n.available_locales.map(&:to_s).include?(attrs[:locale].to_s)
        if params[:password].present?
          return render_errors([ I18n.t("identity.invalid_credentials") ], code: :unauthorized) if current_user.password_digest.present? && !current_user.authenticate(params[:current_password].to_s)
          attrs[:password] = params[:password]
        end
        if current_user.update(attrs.compact)
          render json: { user: Serializers.user(current_user) }
        else
          render_errors(current_user.errors.full_messages)
        end
      end
    end
  end
end
