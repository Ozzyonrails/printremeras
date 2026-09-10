require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Printremeras
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "America/Argentina/Buenos_Aires"

    # Locales: es (default) and ru. Adding a locale = add config/locales/*.<code>.yml and frontend/src/locales/<code>.json
    config.i18n.available_locales = %i[es ru]
    config.i18n.default_locale = :es
    config.i18n.fallbacks = [ :es ]

    config.active_job.queue_adapter = :solid_queue
    config.active_storage.variant_processor = :vips
    config.active_storage.queues.analysis = :default
    config.active_storage.queues.purge = :default

    # Generators
    config.generators do |g|
      g.orm :active_record, primary_key_type: :bigint
      g.helper false
      g.assets false
    end

    # --- Adapter registry (ports & adapters, see docs/ARCHITECTURE.md) ---
    # Every external dependency is resolved through config.x so an implementation
    # can be swapped by changing one line (or one ENV var) without touching call sites.
    config.x.payments.gateway      = ENV.fetch("PAYMENTS_GATEWAY", Rails.env.production? ? "Payments::MercadoPagoGateway" : "Payments::FakeGateway")
    config.x.notifications.channels = { email: "Notifications::EmailChannel" }
    config.x.shipping.providers     = { pickup: "Shipping::PickupProvider", courier: "Shipping::CabaCourierProvider" }
    # Artwork upscaling. NullProvider only marks low-resolution artwork; point this at a
    # paid service adapter to actually improve it.
    config.x.image_enhancement.provider = ENV.fetch("IMAGE_ENHANCEMENT_PROVIDER", "ImageEnhancement::NullProvider")
    config.x.rendering.preview_renderer    = "Rendering::PreviewRenderer"
    config.x.rendering.print_file_renderer = "Rendering::PrintFileRenderer"

    # Object storage: two logical buckets (public/private). Concrete service
    # depends on environment, see config/storage.yml
    storage_backend = ENV.fetch("STORAGE_BACKEND") { Rails.env.production? ? "s3" : (Rails.env.test? ? "test" : "local") }
    config.x.storage.public_service  = :"#{storage_backend}_public"
    config.x.storage.private_service = :"#{storage_backend}_private"

    config.x.app.host = ENV.fetch("APP_HOST", "localhost:3000")
    config.x.app.protocol = ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
    config.x.app.public_url = "#{config.x.app.protocol}://#{config.x.app.host}"
    config.x.app.name = ENV.fetch("APP_NAME", "Printremeras")
    config.x.mailer.from = ENV.fetch("MAIL_FROM", "no-reply@printremeras.local")
    config.x.mailer.operator_email = ENV.fetch("OPERATOR_EMAIL", "ops@printremeras.local")
  end
end
