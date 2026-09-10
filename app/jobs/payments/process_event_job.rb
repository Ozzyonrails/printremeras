module Payments
  class ProcessEventJob < ApplicationJob
    queue_as :payments
    retry_on Payments::Gateway::Error, wait: :polynomially_longer, attempts: 8

    def perform(payment_event_id)
      Payments::ProcessEvent.call(payment_event: PaymentEvent.find(payment_event_id))
    end
  end
end
