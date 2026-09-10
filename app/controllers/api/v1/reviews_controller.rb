module Api
  module V1
    class ReviewsController < BaseController
      before_action :require_user!, only: :create

      # GET /api/v1/reviews?template_id=&catalog_item_id=&page=
      def index
        scope = Review.visible.includes(:user, order: :items, published_photos_attachments: :blob)
        scope = scope.for_template(params[:template_id]) if params[:template_id].present?
        scope = scope.for_catalog_item(params[:catalog_item_id]) if params[:catalog_item_id].present?
        page = params[:page].to_i.clamp(1, 1000)
        per = 24
        rows = scope.offset((page - 1) * per).limit(per + 1).to_a
        render json: { reviews: rows.first(per).map { |r| Serializers.review(r) }, page: page, has_more: rows.size > per }
      end

      # POST /api/v1/orders/:number/review
      def create
        order = current_user.orders.find_by!(number: params[:number])
        result = Reviews::Submit.call(order: order, user: current_user, rating: params[:rating], body: params[:body], photo_signed_ids: params[:photos])
        render_result(result) { |r| render json: { review: Serializers.review(r.review, owner: true) }, status: :created }
      end
    end
  end
end
