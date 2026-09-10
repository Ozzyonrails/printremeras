module Reviews
  # Subscriber to review_approved: one coupon per approved review, never twice.
  class IssueReward
    def self.call(event:, payload:)
      review = Review.find(payload[:review_id])
      return if review.coupon_id.present? || !review.approved?

      result = Coupons::Issue.call(attributes: {
        discount_type: "percentage", discount_value: Setting.review_reward_percent, owner: review.user,
        source: "review_reward", max_uses: 1, valid_from: Time.current, valid_until: Setting.review_coupon_days.days.from_now,
        note: "Review reward for order #{review.order.number}"
      })
      raise result.error_message if result.failure?
      review.update!(coupon: result.coupon)
    end
  end
end
