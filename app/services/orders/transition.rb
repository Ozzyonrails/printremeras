module Orders
  # The order state machine (§13). Only edges listed here are permitted. Every transition
  # is recorded in order_status_transitions and (for staff) the audit log, and publishes
  # order_status_changed plus a specific event where one exists.
  class Transition < ApplicationService
    TRANSITIONS = {
      "draft"            => %w[pending_approval awaiting_payment cancelled],
      "pending_approval" => %w[awaiting_payment rejected cancelled],
      "awaiting_payment" => %w[paid cancelled problem],
      "paid"             => %w[preparing cancelled problem refunded],
      "preparing"        => %w[in_production cancelled problem],
      "in_production"    => %w[awaiting_courier ready_for_pickup cancelled problem],
      "awaiting_courier" => %w[in_transit problem],
      "ready_for_pickup" => %w[delivered problem],
      "in_transit"       => %w[delivered problem],
      "delivered"        => %w[problem refunded],
      "problem"          => %w[awaiting_payment paid preparing in_production awaiting_courier ready_for_pickup in_transit delivered refunded cancelled],
      "rejected"         => [],
      "cancelled"        => [],
      "refunded"         => []
    }.freeze

    EVENTS = {
      "awaiting_payment" => :order_approved, "rejected" => :order_rejected, "paid" => :order_paid,
      "cancelled" => :order_cancelled, "refunded" => :order_refunded, "problem" => :order_problem
    }.freeze

    def self.allowed?(from, to) = TRANSITIONS.fetch(from, []).include?(to)
    def self.next_states(order) = TRANSITIONS.fetch(order.status, [])

    def initialize(order:, to:, actor: nil, reason: nil, skip_event: false)
      @order = order
      @to = to.to_s
      @actor = actor
      @reason = reason
      @skip_event = skip_event
    end

    def call
      from = @order.status
      unless self.class.allowed?(from, @to)
        return failure([ I18n.t("orders.errors.invalid_transition", from: from, to: @to) ], code: :invalid_transition)
      end
      if @to == "ready_for_pickup" && !@order.pickup? || @to == "awaiting_courier" && !@order.courier?
        return failure([ I18n.t("orders.errors.wrong_fulfilment") ], code: :invalid_transition)
      end

      Order.transaction do
        attrs = { status: @to }
        attrs[:paid_at] = Time.current if @to == "paid"
        attrs[:delivered_at] = Time.current if @to == "delivered"
        attrs[:cancelled_at] = Time.current if @to == "cancelled"
        attrs[:rejection_reason] = @reason if @to == "rejected"
        attrs[:problem_note] = @reason if @to == "problem"
        @order.update!(attrs)
        @order.status_transitions.create!(from_status: from, to_status: @to, actor: @actor, reason: @reason)
        AuditLog.record!(action: "order.status_changed", admin_user: @actor, subject: @order, change_set: { "from" => from, "to" => @to, "reason" => @reason }) if @actor.is_a?(AdminUser)
      end

      unless @skip_event
        DomainEvents.publish(:order_status_changed, order_id: @order.id, from: from, to: @to)
        DomainEvents.publish(EVENTS[@to], order_id: @order.id, from: from) if EVENTS[@to]
      end
      success(order: @order, from: from, to: @to)
    end
  end
end
