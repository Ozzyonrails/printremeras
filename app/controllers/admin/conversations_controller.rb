module Admin
  class ConversationsController < BaseController
    def index
      @conversations = paginate(Conversation.includes(:user).by_activity)
    end

    def show
      @conversation = Conversation.includes(:user).find(params[:id])
      Messaging::MarkRead.call(conversation: @conversation, reader: current_admin)
      @messages = @conversation.messages.includes(:sender, :order, attachments_attachments: :blob)
      @orders = @conversation.user.orders.placed.recent.limit(30)
      respond_to do |format|
        format.html
        format.json { render json: { messages: @messages.map { |m| Messaging::MessageSerializer.call(m) } } }
      end
    end
  end
end
