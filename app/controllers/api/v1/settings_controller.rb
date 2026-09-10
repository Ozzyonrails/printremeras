module Api
  module V1
    class SettingsController < BaseController
      def show
        render json: { settings: Serializers.public_settings }
      end
    end
  end
end
