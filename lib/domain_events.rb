# Internal event bus. State changes publish events; behaviour is added by subscribing
# (config/initializers/domain_events.rb). Every subscriber runs in its own background
# job after the surrounding transaction commits, so a failing subscriber can neither
# roll back the publisher nor block sibling subscribers.
module DomainEvents
  CATALOGUE = %i[
    order_created order_approved order_rejected order_paid order_status_changed
    order_cancelled order_refunded order_problem payment_failed
    review_submitted review_approved review_rejected coupon_issued
    message_created design_uploaded
    design_flagged_low_quality design_enhancement_requested design_enhanced design_enhancement_failed
  ].freeze

  class UnknownEvent < StandardError; end

  class << self
    def subscriptions
      @subscriptions ||= Hash.new { |h, k| h[k] = [] }
    end

    def subscribe(event, to:)
      validate!(event)
      subscriptions[event.to_sym] << to.to_s unless subscriptions[event.to_sym].include?(to.to_s)
    end

    def subscribers_for(event)
      subscriptions[event.to_sym]
    end

    # Payload must be ActiveJob-serialisable (ids, strings, numbers).
    def publish(event, **payload)
      validate!(event)
      handlers = subscribers_for(event).dup
      payload = payload.deep_stringify_keys
      ActiveSupport::Notifications.instrument("domain_event.published", event: event, payload: payload)
      ActiveRecord.after_all_transactions_commit do
        handlers.each { |handler| DomainEvents::DispatchJob.perform_later(event.to_s, handler, payload) }
      end
    end

    def reset!
      @subscriptions = nil
    end

    private

    def validate!(event)
      raise UnknownEvent, "#{event} is not in DomainEvents::CATALOGUE" unless CATALOGUE.include?(event.to_sym)
    end
  end
end
