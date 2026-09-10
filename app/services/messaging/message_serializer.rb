module Messaging
  class MessageSerializer
    def self.call(message)
      {
        id: message.id, body: message.body, from_admin: message.from_admin?, sender_name: message.from_admin? ? message.sender.name : message.sender.display_name,
        created_at: message.created_at.iso8601, read_at: message.read_at&.iso8601,
        order: message.order && { number: message.order.number, status: message.order.status, total_cents: message.order.total_cents,
                                  preview_url: Rendering::Urls.order_preview_url(message.order) },
        attachments: message.attachments.map { |a| { id: a.id, filename: a.filename.to_s, url: Rails.application.routes.url_helpers.rails_blob_path(a, only_path: true), image: a.image? } }
      }
    end
  end
end
