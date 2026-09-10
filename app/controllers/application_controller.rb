class ApplicationController < ActionController::Base
  include LocaleResolution
  include CustomerAuthentication

  allow_browser versions: :modern, block: -> { head :upgrade_required }, unless: -> { request.format.json? || request.path.start_with?("/api", "/webhooks") }

  before_action { Current.request_id = request.request_id }
end
