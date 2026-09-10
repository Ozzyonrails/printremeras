# Adapter registry (ports & adapters). Call sites never reference a vendor class;
# they resolve the configured implementation here. Configuration lives in
# config/application.rb (config.x.*) and can be overridden with ENV vars.
module Adapters
  class NotRegistered < StandardError; end

  class << self
    def payment_gateway
      resolve(Rails.configuration.x.payments.gateway).new
    end

    def notification_channel(name)
      klass = Rails.configuration.x.notifications.channels.fetch(name.to_sym) { raise NotRegistered, "notification channel #{name}" }
      resolve(klass).new
    end

    def notification_channel_names
      Rails.configuration.x.notifications.channels.keys
    end

    def shipping_provider(method)
      klass = Rails.configuration.x.shipping.providers.fetch(method.to_sym) { raise NotRegistered, "shipping provider #{method}" }
      resolve(klass).new
    end

    def shipping_methods
      Rails.configuration.x.shipping.providers.keys
    end

    def image_enhancement_provider
      resolve(Rails.configuration.x.image_enhancement.provider).new
    end

    def preview_renderer
      resolve(Rails.configuration.x.rendering.preview_renderer).new
    end

    def print_file_renderer
      resolve(Rails.configuration.x.rendering.print_file_renderer).new
    end

    private

    def resolve(class_name)
      class_name.to_s.constantize
    end
  end
end
