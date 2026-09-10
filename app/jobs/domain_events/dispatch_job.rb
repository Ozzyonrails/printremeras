module DomainEvents
  class DispatchJob < ApplicationJob
    queue_as :events
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(event, handler, payload)
      handler.constantize.call(event: event.to_sym, payload: payload.with_indifferent_access)
    end
  end
end
