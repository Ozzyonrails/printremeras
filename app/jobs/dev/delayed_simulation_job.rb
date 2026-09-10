module Dev
  class DelayedSimulationJob < ApplicationJob
    queue_as :default
    def perform(payment_id, status)
      Adapters.payment_gateway.simulate!(payment: Payment.find(payment_id), status: status)
    end
  end
end
