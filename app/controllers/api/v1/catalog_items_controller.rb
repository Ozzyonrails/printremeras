module Api
  module V1
    class CatalogItemsController < BaseController
      def index
        scope = CatalogItem.published.ordered.includes(:template, preview_attachment: :blob)
        scope = scope.where("tags @> ARRAY[?]::varchar[]", params[:tag]) if params[:tag].present?
        render json: { catalog_items: scope.map { |c| Serializers.catalog_item(c) }, tags: CatalogItem.published.pluck(:tags).flatten.tally.sort_by { |_, n| -n }.map(&:first) }
      end

      def show
        item = CatalogItem.published.includes(template: [ :template_sizes, print_areas: { mockup_attachment: :blob } ]).find_by!(slug: params[:slug])
        render json: { catalog_item: Serializers.catalog_item(item, full: true),
                       reviews: Review.visible.for_catalog_item(item.id).includes(:user, published_photos_attachments: :blob).limit(12).map { |r| Serializers.review(r) } }
      end

      # POST /api/v1/catalog_items/:slug/customize — copy placements into the cart to edit
      def customize
        item = CatalogItem.published.find_by!(slug: params[:slug])
        result = Catalog::CustomizeFromCatalog.call(catalog_item: item, cart: current_cart, template_size_id: params[:template_size_id], owner: current_owner)
        render_result(result) { |r| render json: { cart_item: Serializers.cart_item(r.cart_item), cart: Serializers.cart(current_cart.reload), cart_quantity: current_cart.total_quantity }, status: :created }
      end
    end
  end
end
