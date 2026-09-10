module Api
  module V1
    class MessagesController < BaseController
      before_action :require_user!

      def index
        conversation = Conversation.for_user(current_user)
        Messaging::MarkRead.call(conversation: conversation, reader: current_user)
        messages = conversation.messages.includes(:sender, :order, attachments_attachments: :blob).last(100)
        render json: { conversation_id: conversation.id, messages: messages.map { |m| Messaging::MessageSerializer.call(m) },
                       orders: current_user.orders.placed.recent.limit(20).map { |o| Serializers.order(o) } }
      end

      def create
        conversation = Conversation.for_user(current_user)
        result = Messaging::SendMessage.call(conversation: conversation, sender: current_user, body: params[:body], order_id: params[:order_id], attachment_signed_ids: params[:attachments])
        render_result(result) { |r| render json: { message: Messaging::MessageSerializer.call(r.message) }, status: :created }
      end
    end
  end
end
