module Notifications
  class EmailChannel < Channel
    OPERATOR = :operator

    def name = :email

    def supports?(recipient) = recipient == OPERATOR || recipient.respond_to?(:email)

    def deliver(event:, recipient:, payload:)
      if recipient == OPERATOR
        return unless Notifications::OperatorMailer.respond_to?(event)
        Notifications::OperatorMailer.with(payload).public_send(event).deliver_now
      else
        return unless Notifications::CustomerMailer.respond_to?(event)
        Notifications::CustomerMailer.with(payload.merge(user: recipient)).public_send(event).deliver_now
      end
    end
  end
end
