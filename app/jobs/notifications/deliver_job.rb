module Notifications
  class DeliverJob < ApplicationJob
    queue_as :notifications
    retry_on StandardError, wait: :polynomially_longer, attempts: 6

    def perform(event, recipient_kind, channel_name, payload)
      payload = payload.symbolize_keys
      channel = Adapters.notification_channel(channel_name)
      recipient = resolve_recipient(recipient_kind, payload)
      return if recipient.nil? || !channel.supports?(recipient)

      locale = recipient.respond_to?(:locale) ? recipient.locale : I18n.default_locale
      I18n.with_locale(locale.presence || I18n.default_locale) { channel.deliver(event: event.to_sym, recipient: recipient, payload: payload) }
    end

    private

    def resolve_recipient(kind, payload)
      case kind.to_s
      when "operator" then Notifications::EmailChannel::OPERATOR
      when "customer" then payload[:order]&.user || payload[:review]&.user || payload[:user]
      when "counterpart"
        message = payload[:message]
        message.from_admin? ? message.conversation.user : Notifications::EmailChannel::OPERATOR
      end
    end
  end
end
