module Reviews
  class Reject < ApplicationService
    def initialize(review:, admin_user:, reason:)
      @review = review
      @admin = admin_user
      @reason = reason.to_s.strip
    end

    def call
      return failure([ I18n.t("reviews.errors.not_pending") ]) unless @review.pending?
      return failure([ I18n.t("orders.errors.reason_required") ]) if @reason.blank?
      @review.update!(status: "rejected", published: false, reviewed_by: @admin, reviewed_at: Time.current, rejection_reason: @reason)
      AuditLog.record!(action: "review.rejected", admin_user: @admin, subject: @review, change_set: { "reason" => @reason })
      DomainEvents.publish(:review_rejected, review_id: @review.id)
      success(review: @review)
    end
  end
end
