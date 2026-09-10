module Messaging
  class SendMessage < ApplicationService
    def initialize(conversation:, sender:, body:, order_id: nil, attachment_signed_ids: [])
      @conversation = conversation
      @sender = sender
      @body = body.to_s.strip
      @order_id = order_id
      @attachment_ids = Array(attachment_signed_ids).reject(&:blank?)
    end

    def call
      order = @order_id.present? ? @conversation.user.orders.find_by(id: @order_id) : nil
      return failure([ I18n.t("messages.errors.unknown_order") ]) if @order_id.present? && order.nil?

      message = @conversation.messages.new(sender: @sender, body: @body, order: order)
      blobs = @attachment_ids.filter_map { |sid| ActiveStorage::Blob.find_signed(sid) }
      message.attachments.attach(blobs) if blobs.any?

      Message.transaction do
        return failure(message.errors.full_messages) unless message.save
        if message.from_admin?
          @conversation.update!(last_message_at: message.created_at, unread_for_user: @conversation.unread_for_user + 1)
        else
          @conversation.update!(last_message_at: message.created_at, unread_for_admin: @conversation.unread_for_admin + 1)
        end
      end
      Messaging::Broadcast.call(message: message)
      DomainEvents.publish(:message_created, message_id: message.id)
      success(message: message)
    end
  end
end
