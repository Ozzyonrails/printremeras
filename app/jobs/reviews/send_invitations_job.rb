module Reviews
  # Daily: invite customers whose orders were delivered N days ago and have no review yet.
  class SendInvitationsJob < ApplicationJob
    queue_as :default

    def perform
      day = Setting.review_invitation_delay_days.days.ago
      Order.where(status: "delivered", delivered_at: day.beginning_of_day..day.end_of_day).left_joins(:review).where(reviews: { id: nil }).find_each do |order|
        Notifications::Deliver.call(:review_invitation, order: order)
      end
    end
  end
end
