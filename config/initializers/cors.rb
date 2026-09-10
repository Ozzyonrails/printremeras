# The SPA is served from the same origin in production (public/app) and through the Vite
# proxy in development, so CORS is only needed when FRONTEND_ORIGIN points elsewhere.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").split(","))
    resource "/api/*", headers: :any, methods: %i[get post put patch delete options head], credentials: true
    resource "/rails/active_storage/*", headers: :any, methods: %i[get post put options head], credentials: true
  end
end
