module Rendering
  # URL helpers for images shared by API serializers, admin views and the chat.
  module Urls
    module_function

    def routes = Rails.application.routes.url_helpers

    # Accepts a single attachment (has_one_attached / an element of has_many_attached)
    # or an attachment proxy; returns nil when nothing is attached.
    def attached?(attachment)
      return false if attachment.nil?
      attachment.respond_to?(:attached?) ? attachment.attached? : attachment.present?
    end

    def variant_path(attachment, variant_name)
      return nil unless attached?(attachment)
      routes.rails_representation_path(attachment.variant(variant_name), only_path: true)
    rescue ActiveStorage::InvariableError
      routes.rails_blob_path(attachment, only_path: true)
    end

    def blob_path(attachment)
      attached?(attachment) ? routes.rails_blob_path(attachment, only_path: true) : nil
    end

    def order_preview_url(order)
      item = order.items.detect { |i| i.preview.attached? } || order.items.first
      return nil unless item
      item.preview.attached? ? variant_path(item.preview, :thumb) : template_thumb(item.template)
    end

    def template_thumb(template)
      area = template.front_area || template.print_areas.first
      area && variant_path(area.mockup, :thumb)
    end
  end
end
