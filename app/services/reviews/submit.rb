module Reviews
  # Customer submits (or resubmits once after rejection) a photo review for a delivered order.
  class Submit < ApplicationService
    def initialize(order:, user:, rating:, body: nil, photo_signed_ids: [])
      @order = order
      @user = user
      @rating = rating.to_i
      @body = body.to_s.strip
      @photo_ids = Array(photo_signed_ids).reject(&:blank?)
    end

    def call
      return failure([ I18n.t("reviews.errors.not_yours") ], code: :forbidden) unless @order.user_id == @user.id
      return failure([ I18n.t("reviews.errors.not_delivered") ], code: :invalid) unless @order.delivered?
      return failure([ I18n.t("reviews.errors.window_closed", days: Setting.review_window_days) ], code: :invalid) unless @order.review_window_open?
      min, max = Setting.review_min_photos, Setting.review_max_photos
      return failure([ I18n.t("reviews.errors.photos_required", min: min, max: max) ], code: :invalid) unless @photo_ids.size.between?([ min, 1 ].max, max)

      review = @order.review
      if review
        return failure([ I18n.t("reviews.errors.already_submitted") ], code: :invalid) unless review.can_resubmit?
        review.assign_attributes(status: "pending", rejection_reason: nil, reviewed_by: nil, reviewed_at: nil, submission_count: review.submission_count + 1)
      else
        review = Review.new(order: @order, user: @user)
      end
      review.assign_attributes(rating: @rating, body: @body.presence)

      blobs = @photo_ids.filter_map { |sid| ActiveStorage::Blob.find_signed(sid) }
      return failure([ I18n.t("reviews.errors.invalid_photo") ], code: :invalid) if blobs.size != @photo_ids.size || blobs.any? { |b| !b.image? }
      return failure([ I18n.t("designs.errors.too_large", mb: Setting.max_upload_bytes / 1.megabyte) ]) if blobs.any? { |b| b.byte_size > Setting.max_upload_bytes }

      Review.transaction do
        review.photos.purge_later if review.persisted? && review.photos.attached?
        review.photos.attach(blobs)
        return failure(review.errors.full_messages) unless review.save
      end
      DomainEvents.publish(:review_submitted, review_id: review.id)
      success(review: review)
    end
  end
end
