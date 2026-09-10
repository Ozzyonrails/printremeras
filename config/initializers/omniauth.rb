Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_CLIENT_ID"].present?
    provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], { scope: "email,profile", prompt: "select_account" }
  end
end
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.on_failure = proc { |env| Identity::OmniauthCallbacksController.action(:failure).call(env) }
