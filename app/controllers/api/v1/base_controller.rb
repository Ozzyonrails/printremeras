module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :exception
      before_action :set_default_format
      after_action :expose_csrf_token

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: I18n.t("api.not_found") }, status: :not_found
      end
      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: e.message }, status: :bad_request
      end
      rescue_from ActionController::InvalidAuthenticityToken do
        render json: { error: "invalid_csrf_token" }, status: :unprocessable_content
      end

      private

      def set_default_format = request.format = :json

      def expose_csrf_token
        response.set_header("X-CSRF-Token", form_authenticity_token) if protect_against_forgery?
      end

      def require_user!
        render json: { error: I18n.t("api.login_required"), code: "login_required" }, status: :unauthorized unless signed_in?
      end

      def render_result(result, status: :ok, &block)
        if result.success?
          block ? block.call(result) : head(:no_content)
        else
          render_errors(result.errors, code: result.code)
        end
      end

      def render_errors(errors, code: :invalid, status: nil)
        status ||= case code
        when :not_found then :not_found
        when :unauthorized then :unauthorized
        when :forbidden then :forbidden
        when :unavailable, :gateway_error then :service_unavailable
        else :unprocessable_content
        end
        render json: { error: Array(errors).first, errors: Array(errors), code: code }, status: status
      end
    end
  end
end
