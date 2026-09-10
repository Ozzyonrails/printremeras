class AdminConversationsChannel < ApplicationCable::Channel
  def subscribed
    current_admin ? stream_from("admin:conversations") : reject
  end
end
