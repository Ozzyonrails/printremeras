# Subscribers to domain events. Each runs in its own background job after commit.
Rails.application.config.to_prepare do
  DomainEvents.reset!

  DomainEvents.subscribe :order_paid, to: "Orders::DecrementInventory"
  DomainEvents.subscribe :order_paid, to: "Rendering::GeneratePrintFiles"
  DomainEvents.subscribe :order_cancelled, to: "Orders::RestoreInventory"
  DomainEvents.subscribe :order_refunded, to: "Orders::RestoreInventory"

  DomainEvents.subscribe :review_approved, to: "Reviews::IssueReward"
  DomainEvents.subscribe :review_approved, to: "Reviews::PublishPhotos"

  %i[order_created order_approved order_rejected order_paid order_status_changed order_cancelled order_problem order_refunded
     payment_failed review_submitted review_approved review_rejected message_created].each do |event|
    DomainEvents.subscribe event, to: "Notifications::Notify"
  end
end
