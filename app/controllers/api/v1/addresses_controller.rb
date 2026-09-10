module Api
  module V1
    class AddressesController < BaseController
      before_action :require_user!

      def index
        render json: { addresses: current_user.addresses.order(is_default: :desc, id: :asc).map { |a| Serializers.address(a) } }
      end

      def create
        address = current_user.addresses.build(address_params)
        address.is_default = true if current_user.addresses.none?
        courier_errors = Adapters.shipping_provider(:courier).address_errors(address)
        return render_errors(courier_errors) if courier_errors.any?
        address.save ? render(json: { address: Serializers.address(address) }, status: :created) : render_errors(address.errors.full_messages)
      end

      def update
        address = current_user.addresses.find(params[:id])
        address.assign_attributes(address_params)
        courier_errors = Adapters.shipping_provider(:courier).address_errors(address)
        return render_errors(courier_errors) if courier_errors.any?
        address.save ? render(json: { address: Serializers.address(address) }) : render_errors(address.errors.full_messages)
      end

      def destroy
        current_user.addresses.find(params[:id]).destroy!
        head :no_content
      end

      private

      def address_params
        params.require(:address).permit(:recipient_name, :phone, :street, :number, :apartment, :floor, :neighborhood, :postal_code, :city, :notes, :is_default)
      end
    end
  end
end
