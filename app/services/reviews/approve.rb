module Reviews
  class Approve < ApplicationService
    def initialize(review:, admin_user:, published: true)
      @review = review
      @admin = admin_user
      @published = published
    end

    def call
      return failure([ I18n.t("reviews.errors.not_pending") ]) unless @review.pending?
      @review.update!(status: "approved", published: @published, reviewed_by: @admin, reviewed_at: Time.current, rejection_reason: nil)
      AuditLog.record!(action: "review.approved", admin_user: @admin, subject: @review, change_set: { "published" => @published })
      DomainEvents.publish(:review_approved, review_id: @review.id)
      success(review: @review)
    end
  end
end
