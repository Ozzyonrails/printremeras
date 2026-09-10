module Messaging
  class MarkRead < ApplicationService
    def initialize(conversation:, reader:)
      @conversation = conversation
      @reader = reader
    end

    def call
      if @reader.is_a?(AdminUser)
        @conversation.messages.where(sender_type: "User", read_at: nil).update_all(read_at: Time.current)
        @conversation.update!(unread_for_admin: 0)
      else
        @conversation.messages.where(sender_type: "AdminUser", read_at: nil).update_all(read_at: Time.current)
        @conversation.update!(unread_for_user: 0)
      end
      success
    end
  end
end
