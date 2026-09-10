module Admin
  class ReviewsController < BaseController
    def index
      status = Review::STATUSES.include?(params[:status]) ? params[:status] : "pending"
      @status = status
      @reviews = paginate(Review.where(status: status).includes(:user, :order, :coupon, photos_attachments: :blob).order(created_at: :desc))
      @counts = Review.group(:status).count
    end

    def show
      @review = Review.includes(:user, :coupon, order: :items, photos_attachments: :blob).find(params[:id])
    end

    def approve
      review = Review.find(params[:id])
      result = Reviews::Approve.call(review: review, admin_user: current_admin, published: params[:published] != "0")
      redirect_to admin_reviews_path, result.success? ? { notice: t("admin.reviews.approved") } : { alert: result.error_message }
    end

    def reject
      review = Review.find(params[:id])
      result = Reviews::Reject.call(review: review, admin_user: current_admin, reason: params[:reason])
      redirect_to result.success? ? admin_reviews_path : admin_review_path(review), result.success? ? { notice: t("admin.reviews.rejected") } : { alert: result.error_message }
    end

    # Toggle storefront visibility of an approved review.
    def update
      review = Review.find(params[:id])
      review.update!(published: params[:published] == "1")
      audit!("review.published_changed", review, { "published" => review.published })
      redirect_back fallback_location: admin_reviews_path(status: "approved"), notice: t("admin.saved")
    end
  end
end
