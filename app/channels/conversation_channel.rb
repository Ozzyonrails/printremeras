class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = if current_admin
      Conversation.find_by(id: params[:conversation_id])
    else
      Conversation.for_user(current_user)
    end
    conversation ? stream_from("conversation:#{conversation.id}") : reject
  end
end
