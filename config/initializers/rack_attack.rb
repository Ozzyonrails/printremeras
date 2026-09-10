class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new unless Rails.env.production?

  throttle("api/ip", limit: 300, period: 1.minute) { |req| req.ip if req.path.start_with?("/api/") }
  throttle("logins/ip", limit: 10, period: 1.minute) { |req| req.ip if req.path == "/api/v1/session" && req.post? }
  throttle("registrations/ip", limit: 5, period: 1.minute) { |req| req.ip if req.path == "/api/v1/registration" && req.post? }
  throttle("password_resets/ip", limit: 5, period: 10.minutes) { |req| req.ip if req.path == "/api/v1/password_resets" && req.post? }
  throttle("reviews/ip", limit: 5, period: 1.hour) { |req| req.ip if req.path.match?(%r{\A/api/v1/orders/[^/]+/review\z}) && req.post? }
  throttle("designs/ip", limit: 60, period: 1.hour) { |req| req.ip if req.path == "/api/v1/designs" && req.post? }
  throttle("admin_logins/ip", limit: 10, period: 1.minute) { |req| req.ip if req.path == "/admin/session" && req.post? }

  self.throttled_responder = lambda do |_req|
    [ 429, { "content-type" => "application/json" }, [ { error: "rate_limited" }.to_json ] ]
  end
end
Rails.application.config.middleware.use Rack::Attack
