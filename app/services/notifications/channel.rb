module Notifications
  # Port for delivery channels (email now; WhatsApp/SMS/Telegram later). A channel
  # receives the event name, the recipient (User or AdminUser-like operator target)
  # and a payload hash of ids. It must be idempotent-safe: jobs may retry.
  class Channel
    def name = raise(NotImplementedError)
    def deliver(event:, recipient:, payload:) = raise(NotImplementedError)
    def supports?(recipient) = true
  end
end
