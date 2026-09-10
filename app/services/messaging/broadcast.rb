module Messaging
  # Realtime fan-out over Solid Cable: the customer's stream and the admin inbox stream.
  class Broadcast < ApplicationService
    def initialize(message:)
      @message = message
    end

    def call
      payload = Messaging::MessageSerializer.call(@message)
      ActionCable.server.broadcast("conversation:#{@message.conversation_id}", { type: "message", message: payload })
      ActionCable.server.broadcast("admin:conversations", { type: "message", conversation_id: @message.conversation_id, message: payload,
                                                             unread_for_admin: @message.conversation.reload.unread_for_admin })
      success
    end
  end
end
