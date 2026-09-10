module Admin
  class MessagesController < BaseController
    def create
      conversation = Conversation.find(params[:conversation_id])
      result = Messaging::SendMessage.call(conversation: conversation, sender: current_admin, body: params[:body], order_id: params[:order_id].presence)
      respond_to do |format|
        format.json { result.success? ? render(json: { message: Messaging::MessageSerializer.call(result.message) }) : render(json: { error: result.error_message }, status: :unprocessable_content) }
        format.html { redirect_to admin_conversation_path(conversation), result.success? ? {} : { alert: result.error_message } }
      end
    end
  end
end
