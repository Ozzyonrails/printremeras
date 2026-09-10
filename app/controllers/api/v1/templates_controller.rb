module Api
  module V1
    class TemplatesController < BaseController
      def index
        templates = Template.active.ordered.includes(:template_sizes, print_areas: { mockup_attachment: :blob })
        render json: { templates: templates.select(&:ready_for_sale?).map { |t| Serializers.template(t) } }
      end

      def show
        template = Template.active.includes(:template_sizes, print_areas: { mockup_attachment: :blob }).find_by!(slug: params[:slug])
        render json: { template: Serializers.template(template, full: true),
                       reviews: Review.visible.for_template(template.id).includes(:user, published_photos_attachments: :blob).limit(12).map { |r| Serializers.review(r) } }
      end
    end
  end
end
