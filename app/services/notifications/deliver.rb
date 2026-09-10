module Notifications
  # Entry point: Notifications::Deliver.call(:order_paid, order: order). Recipients per
  # event come from MATRIX (§15); channels per event come from Setting.notification_channels
  # ({"default" => ["email"], "order_shipped" => ["email","whatsapp"]}). Each delivery is
  # its own job so a failing channel never blocks another.
  class Deliver < ApplicationService
    MATRIX = {
      order_created:      %i[operator],
      order_approved:     %i[customer],
      order_rejected:     %i[customer],
      order_paid:         %i[customer operator],
      order_status_changed: %i[customer],
      order_cancelled:    %i[customer operator],
      order_problem:      %i[customer operator],
      order_refunded:     %i[customer],
      payment_failed:     %i[customer],
      review_submitted:   %i[operator],
      review_approved:    %i[customer],
      review_rejected:    %i[customer],
      review_invitation:  %i[customer],
      message_created:    %i[counterpart]
    }.freeze

    def initialize(event, channels: nil, **payload)
      @event = event.to_sym
      @channels = channels
      @payload = payload
    end

    def call
      recipients = MATRIX.fetch(@event, [])
      channels = @channels || configured_channels
      recipients.each do |kind|
        channels.each do |channel|
          Notifications::DeliverJob.perform_later(@event.to_s, kind.to_s, channel.to_s, serializable_payload)
        end
      end
      success
    end

    private

    def configured_channels
      cfg = Setting.notification_channels || {}
      Array(cfg[@event.to_s].presence || cfg["default"].presence || [ "email" ]).map(&:to_sym) & Adapters.notification_channel_names
    end

    def serializable_payload
      @payload.to_h.transform_keys(&:to_s)
    end
  end
end
